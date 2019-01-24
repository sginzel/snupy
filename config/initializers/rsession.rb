# This file initializes the necessary libararies and connections for rserver
#
# puts "Establishing RSESSION".red
if (1 == 0) then
	#rsession = Rserve.new(
	#										 hostname: "127.0.0.1",
	#										 port_number: 6311,
	#										 username: nil,
	#										 password: nil,
	#										 session: nil
	#)
end
at_exit do
	# rsession.close
	#puts "CLOSING R SESSION".red
end