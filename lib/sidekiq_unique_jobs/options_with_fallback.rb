module SidekiqUniqueJobs
  module OptionsWithFallback
    def self.included(base)
      base.class_attribute :lock_cache unless base.respond_to?(:lock_cache)
      base.lock_cache ||= {}
    end

    def unique_enabled?
      unique_on = options[k = UNIQUE_KEY] || item[k]
      ignore_on = options[k = UNIQUE_IGNORE_SCHEDULED_JOBS_KEY] || item[k]

      if ignore_on
        schedule_on = options[k = SCHEDULE_KEY] || item[k]
        unique_on and not schedule_on
      else
        unique_on
      end
    end

    def unique_disabled?
      !unique_enabled?
    end

    def log_duplicate_payload?
      options[LOG_DUPLICATE_KEY] || item[LOG_DUPLICATE_KEY]
    end

    def lock
      @lock = lock_class.new(item)
    end

    def lock_class
      lock_cache[unique_lock.to_sym] ||= "SidekiqUniqueJobs::Lock::#{unique_lock.to_s.classify}".constantize
    end

    def unique_lock
      @unique_lock ||=
        if options.key?(UNIQUE_KEY) && options[UNIQUE_KEY].to_s == 'true'
          warn('unique: true is no longer valid. Please set it to the type of lock required like: ' \
               '`unique: :until_executed`')
          options[UNIQUE_LOCK_KEY] || SidekiqUniqueJobs.default_lock
        else
          lock_type || SidekiqUniqueJobs.default_lock
        end
    end

    def lock_type
      lock_type_from(options) || lock_type_from(item)
    end

    def lock_type_from(hash, key = UNIQUE_KEY)
      if (klass = hash[key])
        return nil if klass.is_a?(TrueClass)
        klass
      end
    end

    def options
      @options ||= worker_class.get_sidekiq_options if worker_class.respond_to?(:get_sidekiq_options)
      @options ||= Sidekiq.default_worker_options
      @options ||= {}
      @options &&= @options.stringify_keys
    end
  end
end
