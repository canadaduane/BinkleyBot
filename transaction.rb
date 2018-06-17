require_relative "format"

class Transaction
  attr_accessor :amount, :fee, :person, :description, :timestamp

  def initialize(amount, fee, person, description, timestamp = Time.now)
    @amount, @fee, @person, @description = [amount, fee, person, description]
    @timestamp = timestamp
    @last_updated_range = nil
  end

  def total
    @amount + @fee
  end

  def dollar_amount(sign = 1)
    format_dollars(@amount, sign)
  end

  def dollar_fee(sign = 1)
    format_dollars(@fee, sign)
  end

  def append_to_sheet(sheet)
    sheet.append_row([
      @timestamp,
      "", # balance column
      @amount,
      @fee,
      @person,
      @description
    ]).tap do |response|
      # Store the last updated range in case we need to "undo" later
      @last_updated_range = response.updates.updated_range
    end
  end

  def undo(sheet)
    if @last_updated_range
      sheet.clear(@last_updated_range)
      @last_updated_range = nil
    end
  end

  def withdraw_description
    "#{dollar_amount(-1)} (+#{dollar_fee(-1)} fee) : #{@person} : \"#{@description}\""
  end

  def to_s
    "#{dollar_amount} (+#{dollar_fee} fee) : #{@person} : \"#{@description}\""
  end
end
