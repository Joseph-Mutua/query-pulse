# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src :self, :data
    policy.img_src :self, :data
    policy.object_src :none
    policy.frame_ancestors :none
    policy.connect_src :self
    policy.script_src :self
    policy.style_src :self, :unsafe_inline
    policy.base_uri :self
    policy.form_action :self
  end

  config.content_security_policy_nonce_generator = ->(request) { request.request_id }
  config.content_security_policy_nonce_directives = %w[script-src]
end
