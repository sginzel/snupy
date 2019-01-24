# TODO using a static tunnel is better, because on the production many processes are spawned and this messes everything up
# Use a system command like "nohup ssh -L ... & echo $! > var/tunnel.pid"
# Maybe fork() is also an option
# start-stop-daemon is probably the best option https://github.com/engineyard/ey-cloud-recipes/blob/master/cookbooks/ssh_tunnel/templates/default/ssh_tunnel.initd.erb
# ssh -nNT -L 12345:localhost:13306 biodb
module SnupyAgain
	class Tunnel
		@@counter = 0
		attr_accessor :gateway, :host, :remote_host, :user, :local_port, :remote_port, :port

		def initialize
			@gateway = nil
			tunnel_config = File.join(Rails.root, 'config','tunnels', 'tunnel.yml')
			if File.exist?tunnel_config then
				tunnel_config = YAML.load(File.open(tunnel_config).read || "") || {}
				tunnel_config_env = tunnel_config[Rails.env]
				if not tunnel_config_env.nil? then
					@host, @remote_host, @user, @local_port, @remote_port = %w(host remote_host user local_port remote_port).map{|k| tunnel_config_env[k]}
					options = {}
					(tunnel_config_env["options"] || {}).each do |k,v|
						options[k.to_sym] = v
					end
					puts "Options: \n" + options.pretty_inspect.to_s.cyan
					#Net::SSH::Gateway.new('biodb', 'sginze2s').open("194.95.66.234", 13306, 12345)
					if @host and @local_port and @remote_host and @remote_port then
						print "Opening tunnel #{@local_port} -> #{host} -> #{@remote_host}:#{@remote_port}...".cyan
						if @gateway.nil? then
							@gateway = Net::SSH::Gateway.new(@host, @user, options)
						else
							print "reusing previous...".yellow
						end
						open_gate()
					else
						puts "Tunnel information for #{Rails.env} environment incomplete".magenta
					end
				else
					puts "No tunnel setup available for #{Rails.env} environment".magenta
				end
			end
		end

		def open_gate
			begin
				@port = @gateway.open(@remote_host, @remote_port, @local_port)
			rescue Errno::EADDRINUSE => e
				# chose another local port than the one described
				puts "need a new port #{@local_port} doesnt work"
				@local_port = Tunnel.find_local_port(@local_port)
				@port = @gateway.open(@remote_host, @remote_port, @local_port)
				print "Using port #{@port} instead...".yellow
			end
			if @port == @local_port then
				@@counter += 1
				puts "ESTABLISHED".green
			else
				puts "FAILED".red
			end
		end

		def close_gateway
			@@counter -= 1
			if @@counter == 0
				if !SnupyAgain::Tunnel.instance.gateway.nil? then
					print "closing SSH tunnel...".yellow
					SnupyAgain::Tunnel.instance.gateway.shutdown!
				end
			end
		end

		def self.find_local_port(starting_port)
			myport = starting_port
			cnt = 0
			port_found = false
			while (!port_found)
				myport = starting_port + cnt
				port_found = Tunnel.port_used(myport)
				cnt += 1
				break if cnt > 1000
			end
			myport
			end

			def self.port_used(port)
				ret = false
				begin
					s = TCPServer.new("127.0.0.1", port)
					s.close
					ret = true
				rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::EADDRINUSE
					ret = false
				end
				ret
			end

		@@instance = Tunnel.new
		def self.instance
			if !@@instance.gateway.nil? then
				if !@@instance.gateway.active? then
					@@instance.open_gate
				end
			end
			return @@instance
		end

	end
end

# Using this look cleaner, but will break everything in production.
#at_exit do
#	print "Closing gateway...".yellow
#	SnupyAgain::Tunnel.instance.close_gateway
#	puts "OK".green
#end