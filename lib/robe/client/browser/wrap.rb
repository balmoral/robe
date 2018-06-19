# The code in 'robe/client/browser/wrap' is in large
# part derived from 'opal-browser' and 'bowser' gems
# by @meh and @jgaskins respectively. Thanks to both.
#
# We need a wrap for javascript browser code that is
# faster and lighter than opal-browser, but with a few
# more bits than bowser.
#
# As required by their licences we include copyright notices:
#
# #########################
# Copyright (C) 2014 by meh
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# ################################
# Copyright (c) 2015 Jamie Gaskins
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

require 'native'
require 'json'
require 'robe/common/promise'
require 'robe/client/browser/wrap/core_ext'
require 'robe/client/browser/wrap/native_fallback'
require 'robe/client/browser/wrap/browser'
require 'robe/client/browser/wrap/cookies'
require 'robe/client/browser/wrap/event'
require 'robe/client/browser/wrap/event_target'
require 'robe/client/browser/wrap/file_list'
require 'robe/client/browser/wrap/http/response'
require 'robe/client/browser/wrap/http/request'
require 'robe/client/browser/wrap/http/form_data'
require 'robe/client/browser/wrap/http'
require 'robe/client/browser/wrap/window/history'
require 'robe/client/browser/wrap/window/location'
require 'robe/client/browser/wrap/window'
require 'robe/client/browser/wrap/element'
require 'robe/client/browser/wrap/cookies'
require 'robe/client/browser/wrap/document'
require 'robe/client/browser/wrap/cookies'

