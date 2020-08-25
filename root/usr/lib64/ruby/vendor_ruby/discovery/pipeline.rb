require 'ostruct'
require 'singleton'
require 'forwardable'

class Pipeline
  include Singleton
  extend SingleForwardable
  attr_reader :data, :gdata

  def initialize
    start_over
    # global workflow data (variables shared for whole app)
    @gdata = OpenStruct.new
  end

  def start_over
    # queue of screens
    @screens = []
    # workflow data (variables shared for set of screens)
    @data = OpenStruct.new
  end

  def cancel(on_cancel = :screen_welcome)
    start_over
    append :screen_welcome
  end

  def prepend screen
    @screens.unshift screen
    log_msg "Pipeline prepend (#{screen.inspect}): #{@screens.inspect}"
    @screens
  end

  def append screen
    @screens << screen
    log_msg "Pipeline append (#{screen.inspect}): #{@screens.inspect}"
    @screens
  end

  def next
    x = @screens.shift
    log_msg "Pipeline next (#{x.inspect}): #{@screens.inspect}"
    x
  end

  def to_s
    @data.to_h.to_a.map do |k, v|
      "#{k}: #{v}"
    end.join("\n")
  end

  def method_missing(method, *args)
    @screens.send(method, *args)
  end
end
