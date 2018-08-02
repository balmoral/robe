module Robe; module Server
  class App

    # target should be one of [database, collection, index]
    # method should be a method appropriate to target
    # args should be an array in json format
    task :dbop, auth: true do |target:, method:, args:|
      # trace __FILE__, __LINE__, self, __method__, "(target: #{target}, method: #{method}, args: #{args}"
      target = target.to_sym
      method = method.to_sym
      args = args ? args.compact : []
      Robe.db.op(target, method, *args).then do |result|
        {
          success: true,
          data: result
        }
      end.fail do |error|
        msg = "Error performing dbop(target: #{target}, method: #{method}, args=#{args}) : #{error}"
        trace __FILE__, __LINE__, self, __method__, " : #{msg}"
        {
          success: false,
          error: msg
        }
      end
    end

  end
end end