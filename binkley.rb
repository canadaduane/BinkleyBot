require 'dotenv/load'
require 'telegram/bot'

token = ENV['TELEGRAM_TOKEN']
# puts ENV['PAYPAL_TOKEN']

class Transaction < Struct.new(:amount, :fee, :from, :message)
  def to_s
    "$#{self.amount} (+$#{self.fee} fee) : #{self.from} : \"#{self.message}\""
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

$transactions = [
  Transaction.new(50.0, 2.99, "Lizz", "taking friends out to lunch")
]

$balance = $transactions.reduce(1000.0) { |total, n| total - n.amount - n.fee }
$last_powerup_time = Time.new(2000) # a long time ago

help_message = <<EOS
/help         this message
/balance      show the JENE fund balance
/history      show a history of transactions
/powerup      send some money, e.g. "/powerup $500 for school tuition"
/oops         undo the last powerup
EOS

Telegram::Bot::Client.run(token) do |bot|
  bot.listen do |message|
    case message.text
    when '/start'
      bot.api.send_message(chat_id: message.chat.id, text: "Hello, #{message.from.first_name}")
    when '/stop'
      bot.api.send_message(chat_id: message.chat.id, text: "Bye, #{message.from.first_name}")
    when '/help'
      bot.api.send_message(chat_id: message.chat.id, text: help_message)
    when '/balance'
      bot.api.send_message(chat_id: message.chat.id, text: "The Johnson Eight Networking & Education Fund has a balance of $#{$balance}")
    when '/history'
      response = $transactions.map{ |t| t.to_s }.join("\n")
      bot.api.send_message(chat_id: message.chat.id, text: response)
    when '/oops'
      if (Time.now - $last_powerup_time) < 60
        oopser = $transactions.pop
        $balance += (oopser.amount + oopser.fee)
        response = "Canceling: #{oopser.to_s}"
        bot.api.send_message(chat_id: message.chat.id, text: response)
        bot.api.send_message(chat_id: message.chat.id, text: "The new fund balance is $#{$balance}")
      else
        bot.api.send_message(chat_id: message.chat.id, text: "Sorry, too late!")
      end
      $last_powerup_time = Time.new(2000)
    when /^\/powerup\s+\$([\d\.]+)\s+(to|for)\s+(.+)$/
      dollars, verb, reason = $1, $2, $3
      dollars = dollars.to_f

      $last_powerup_time = Time.now
      fee = 2.99
      $balance -= (dollars.to_f + fee)
      $transactions << Transaction.new(dollars, fee, message.from.first_name, reason)

      response = "#{compliment message.from.first_name} Sending $#{dollars} your way #{verb} #{reason}"
      bot.api.send_message(chat_id: message.chat.id, text: response)
      
      bot.api.send_message(chat_id: message.chat.id, text: "The new fund balance is $#{$balance}")
    end
  end
end