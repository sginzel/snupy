class ApiKey < ActiveRecord::Base
	establish_connection("#{Rails.env}_api")
	
	belongs_to :user
	attr_accessible :user_id, :token
	@@result = nil
	
	def self.query(statement, &block)
		return nil if statement.nil?
		# finish the result
		if !@@result.nil? then
			begin
				x = @@result.each{|r| r}
			rescue Mysql2::Error => e
			end
		end
		if self.connection.adapter_name == "Mysql2" then
			@@result = dbconnection.query(statement, stream: true, as: :hash) # when we stream the call will be asynchronous
		else
			@@result = self.connection.execute(statement)
		end
		if block_given?
			yield @@result
			return []
		else
			return @@result
		end
	end
	
	def self.dbconnection
		# return nil unless current_user.is_admin?
		self.establish_connection("#{Rails.env}_api") if self.connection.nil?
		self.connection.instance_eval{@connection}
	end
	
	# to create a new apikey we need to jump through some hoops because the ApiKey establishes a new connectin
	# with a read-only user. So we need to user the "normal" datbase connection and create a insert statement manually
	def self.generate(user, overwrite = false)
		apikey = nil
		if user.api_key.nil? or overwrite then
			ActiveRecord::Base.transaction do
				if !user.api_key.nil? and overwrite then
					ApiKey.remove(user.api_key)
				end
				apikey = ApiKey.new({user_id: user.id})
				apikey.generate_token
				sql = SnupyAgain::DatabaseUtils.get_insert_statement(apikey, ApiKey)
				ActiveRecord::Base.connection.execute("INSERT INTO #{sql[:table]} (#{sql[:columns].join(",")}) VALUES (#{sql[:values]})")
			end
		end
		user.api_key
	end
	
	def self.remove(apikey)
		return false if apikey.nil?
		ActiveRecord::Base.transaction do
			ActiveRecord::Base.connection.execute("DELETE FROM #{ApiKey.table_name} WHERE id = #{apikey.id}")
		end
	end
	
	def generate_token
		return false if self.persisted? # don't generate a token when the ApiKey exists. Updating is not allowed.
		begin
			self.token = SecureRandom.hex(32)
		end while (ApiKey.exists? token: self.token)
	end
	
end
