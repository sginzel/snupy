
if 1 == 0 then
	api = ActiveRecord::Base.establish_connection :development_api
	if x = api.connection.adapater_name == "Mysql2" then
		x = api.connection.instance_eval{@connection}.query("SELECT * from variation_calls LIMIT 100000", stream: true) # when we stream the call will be asynchronous
	else
		x = api.connection.execute("SELECT * from variation_calls LIMIT 100000")
	end
	
	y = []
	
	x.each{|r| y << r}
	
	puts y.size
end
