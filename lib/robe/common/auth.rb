module Robe
  module Auth
    # module_function privatises methods
    # when modules/classes include/extend
    extend self

    SIGNATURE_HOOK = '|:|'

    SIGN_IN_SUCCESS = 'success'
    SIGN_IN_INVALID_USER = 'invalid user'
    SIGN_IN_INVALID_PASSWORD = 'invalid password'
  end
end
