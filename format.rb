def format_dollars(amount, sign = 1.0)
  "$" + ("%.2f" % (amount * sign))
end
