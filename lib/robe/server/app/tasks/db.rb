module Robe; module Server
  class App

    # target should be one of [database, collection, index]
    # method should be a method appropriate to target
    # args should be an array in json format
    task :dbop, ->(target:, method:, args: []) {
      trace __FILE__, __LINE__, self, __method__, "(#{target}, #{method}, #{args})"
      target = target.to_sym
      method = method.to_sym
      args.compact!
      trace __FILE__, __LINE__, self, __method__, "(#{target}, #{method}, #{args})" if method.to_sym == :insert_one
      begin
        {
          success: true,
          data: Robe.db.op(target, method, *args)
        }
      rescue DBError => e
        Robe.logger.error(msg)
        {
          success: false,
          error: "Error performing task(target: #{target}, method: #{method}, args=#{args}) => e.to_s"
        }
      end
    }

  end
end end