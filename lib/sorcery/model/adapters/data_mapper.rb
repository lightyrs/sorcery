module Sorcery
  module Model
    module Adapters
      module DataMapper
        def self.included(klass)
          klass.extend ClassMethods
          klass.send(:include, InstanceMethods)
        end

        module InstanceMethods
          def increment(attr)
            self.adjust!(attr.to_sym => 1)
          end
          
          def update_single_attribute(name, value)
            value = value.utc if value.is_a?(ActiveSupport::TimeWithZone)
            self.update(name => value)
          end
        end

        module ClassMethods
          def credential_regex(credential)
            return { :$regex =>  /^#{credential}$/i  }  if (@sorcery_config.downcase_username_before_authenticating)
            return credential
          end

          def find_by_credentials(credentials)
            @sorcery_config.username_attribute_names.each do |attribute|
              @user = where(attribute => credential_regex(credentials[0])).first
              break if @user
            end
            @user
          end

          def find_by_provider_and_uid(provider, uid)
            @user_klass ||= ::Sorcery::Controller::Config.user_class.to_s.constantize
            first(@user_klass.sorcery_config.provider_attribute_name.to_sym => provider, @user_klass.sorcery_config.provider_uid_attribute_name.to_sym => uid)
          end

          def find_by_id(id)
            first(:id => id)
          rescue StandardError
            nil
          end

          def find_by_activation_token(token)
            first(sorcery_config.activation_token_attribute_name.to_sym => token)
          end

          def find_by_remember_me_token(token)
            first(sorcery_config.remember_me_token_attribute_name.to_sym => token)
          end

          def find_by_username(username)
            query = sorcery_config.username_attribute_names.map {|name| {name.to_sym => username}}
            first(query)
          end

          def transaction(&blk)
            tap(&blk)
          end

          def find_by_sorcery_token(token_attr_name, token)
            first(token_attr_name.to_sym => token)
          end

          def find_by_email(email)
            first(sorcery_config.email_attribute_name.to_sym => email)
          end

          def get_current_users
            config = sorcery_config
            where(config.last_activity_at_attribute_name.ne.to_sym => nil) \
            .where("this.#{config.last_logout_at_attribute_name} == null || this.#{config.last_activity_at_attribute_name} > this.#{config.last_logout_at_attribute_name}") \
            .where(config.last_activity_at_attribute_name.gt => config.activity_timeout.seconds.ago.utc).order_by([:_id,:asc])
          end
        end
      end
    end
  end
end