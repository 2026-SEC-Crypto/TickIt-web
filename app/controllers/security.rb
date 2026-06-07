# frozen_string_literal: true

module TickIt
  class Web < Roda
    # -----------------------------------------------------------------------
    # HTTPS enforcement (moved from app.rb)
    # -----------------------------------------------------------------------
    configure :production do
      plugin :redirect_http_to_https
      plugin :hsts, max_age: 31_536_000, include_subdomains: true
    end

    # -----------------------------------------------------------------------
    # Content Security Policy
    # Restricts which sources the browser may load resources from.
    # report-uri sends violation reports to /csp-report so we can monitor them.
    # -----------------------------------------------------------------------
    api_origin = ENV.fetch('API_URL', 'http://localhost:9292/api/v1').split('/api').first

    plugin :content_security_policy do |csp|
      csp.default_src :none
      csp.script_src  :self, :unsafe_inline, 'https://cdn.jsdelivr.net'
      csp.style_src   :self, :unsafe_inline
      csp.img_src     :self, :data, 'https:'
      csp.font_src    :self
      csp.connect_src :self, api_origin
      csp.frame_src   :none
      csp.frame_ancestors :none
      csp.base_uri    :self
      csp.form_action :self
      csp.report_uri  '/csp-report'
    end

    # -----------------------------------------------------------------------
    # Default security response headers
    # Applied to every response automatically.
    # -----------------------------------------------------------------------
    plugin :default_headers,
           'X-Frame-Options'           => 'DENY',
           'X-Content-Type-Options'    => 'nosniff',
           'X-XSS-Protection'          => '0',
           'Referrer-Policy'           => 'strict-origin-when-cross-origin',
           'Permissions-Policy'        => 'geolocation=(), camera=(), microphone=()'
  end
end
