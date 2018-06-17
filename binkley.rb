require 'dotenv/load'
require 'telegram/bot'
require_relative 'gsheets'

REMAINING_BALANCE_CELL = "B2" # sheet range / cell where we can get the remaining balance
PAYPAL_FEE = 2.99

$sheet = GSheets::Client.new.sheet(ENV['GOOGLE_SHEET_DOCUMENT_ID'], "Transactions")


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
    "$" + ("%.2f" % (@amount * sign))
  end

  def dollar_fee(sign = 1)
    "$" + ("%.2f" % (@fee * sign))
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

def compliment(name)
  case rand(10)
  when 0 then "You're awesome, #{name}!"
  when 1 then "Oh yeah! #{name} is gonna change the world!"
  when 2 then "You bet your booties, #{name}, we got you covered!"
  when 3 then "Absolutely, #{name}--you're the best!"
  when 4 then "Roger, #{name}. Keep rockin'!"
  when 5 then "Ok, #{name}! Hope you have a great time."
  when 6 then "The world is better with you in it, #{name}--and good luck!"
  when 7 then "You'll do fine, #{name}. You always do! (Almost!)"
  when 8 then "You're a princess, #{name}, and the people love you."
  when 9 then "Canadians rock! And especially you, #{name}."
  end
end

def remaining_balance
  $sheet.value(REMAINING_BALANCE_CELL)
end

$last_powerup_time = Time.new(2000) # a long time ago
$last_transaction = nil

def help_message
<<-EOS
/help         this message
/balance      show the JENE fund balance
/history      show a history of transactions
/powerup      send some money, e.g. "/powerup $500 for school tuition"
/oops         undo the last powerup
EOS
end

def run
  Telegram::Bot::Client.run(ENV['TELEGRAM_TOKEN']) do |bot|
    bot.listen do |message|
      case message.text
      when '/start'
        bot.api.send_message(chat_id: message.chat.id, text: "Hello, #{message.from.first_name}")
      when '/stop'
        bot.api.send_message(chat_id: message.chat.id, text: "Bye, #{message.from.first_name}")
      when '/help'
        bot.api.send_message(chat_id: message.chat.id, text: help_message)
      when '/balance'
        bot.api.send_message(chat_id: message.chat.id, text: "The Johnson Eight Networking & Education Fund has a balance of $#{remaining_balance}")
      when '/history'
        response = "You can see the transaction history at https://docs.google.com/spreadsheets/d/1r9dSbMUS1svw5UkA9Nhw3ZcGNKoMIdTS0noi1P7dZW8/edit"
        bot.api.send_message(chat_id: message.chat.id, text: response)
      when '/oops'
        if (Time.now - $last_powerup_time) < 60 && !$last_transaction.nil?
          # Reverse the transaction
          $last_transaction.undo($sheet)
          
          response = "Canceling: #{$last_transaction.withdraw_description}"
          bot.api.send_message(chat_id: message.chat.id, text: response)
          bot.api.send_message(chat_id: message.chat.id, text: "The new fund balance is $#{remaining_balance}")
        else
          bot.api.send_message(chat_id: message.chat.id, text: "Sorry, too late! Check the /history")
        end
        $last_powerup_time = Time.new(2000)
      
      when /^\/powerup\s+\$([\d\.]+)\s+(to|for)\s+(.+)$/
        dollars, verb, reason = $1, $2, $3
        dollars = dollars.to_f

        $last_powerup_time = Time.now
        $last_transaction = Transaction.new(-dollars, -PAYPAL_FEE, message.from.first_name, reason)
        $last_transaction.append_to_sheet($sheet)        

        response = "#{compliment message.from.first_name} Sending $#{dollars} your way #{verb} #{reason}"
        bot.api.send_message(chat_id: message.chat.id, text: response)
        
        bot.api.send_message(chat_id: message.chat.id, text: "The new fund balance is $#{remaining_balance}")
      end
    end
  end
end

begin
  run()
rescue StandardError => e
  $stderr.puts "Error: #{e}, retrying..."
  sleep 1
  retry
end
