require 'browser/cookies'

module Browser
  class Cookies

    # callback should expect kwargs cause:, removed:, and cookie:
    def on_change(&callback)
      fail "#{self.class.name}##{__method__} not implemented yet - not sure how to..."
      handler = ->(event) {
        callback.call(
          cause: event.cause.to_sym, # :evicted, :expired, :explicit, :expired_overwrite, :overwrite
          removed: event.removed,
          cookie: {
            name: event.cookie.name,
            value: event.cookie.value,
            domain: event.cookie.domain,
            host_only: event.cookie.hostOnly,
            path: event.cookie.path,
            http_only: event.cookie.httpOnly,
            session: event.cookie.session,
            expiration_date: event.cookie.expirationDate,
            store_id: event.cookie.storeId,
          }
        )
      }
      `window.cookies.onChanged.addListener(handler)`
    end

  end
end

