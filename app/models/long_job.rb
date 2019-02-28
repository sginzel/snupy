# == Description
# This class is a wrapper for the DelayedJob class. This is neccessary because with the delayed job framework you can't automatically cache 
# the result of a function call, trigger callbacks, query the status of a job or handle failure.
# Also this class implements methods to post generic jobs to the queue
# == Attributes
# [delayed_job] A DelayedJob to check the queue
# [handle] Object to call the method on 
# [method] method name
# [parameter] array of parameters the method sould be called with
# [status] status message of the job, must be a Constant
# [status_view] path to the view to be rendered to show the status, default is long_job/show
# [success] ???
# [title] title of the job - if any
# [user] user that submitted the job
# [result] the result of the task that was run. 
# [result_view] path of the view to be rendered, relative to rails root path
# [delayed_job_id] DelayedJob ID
# [checksum] 
#    MD5Sum of the Object class, the method name and the parameters to call. Caclutation: <tt> Digest::MD5.hexdigest([obj.class.to_s, method_name.to_s, args.flatten.map(&:to_s)].flatten.sort.to_s) </tt>
# [error] 
#    Last error Message
# === Read Only
# [obj (read only)]
# [method_name (read only)]
# [args (read only)]
# [job (read only)]
class LongJob < ActiveRecord::Base
	
	belongs_to :delayed_job
	has_and_belongs_to_many :experiments, join_table: :experiment_has_long_jobs
	
	
	attr_accessible :delayed_job, :handle, :method, :parameter, :status, :status_view, :success, :title, :user, :result, :result_view, :delayed_job_id, :checksum, :error, :finished_at, :started_at, :queue
	attr_reader :obj, :method_name, :args, :job
	
	default_scope order('created_at DESC')
	
	# Job is done
	DONE="DONE"
	# Job has failed
	FAILURE="FAILED"
	# Job is being processed now
	RUN="RUNNING"
	# Job is enqueued and waits for execution
	ENQUEUE="ENQUEUED"
	# A generic job is set up and not enqueued yet
	SETUP="SETUP"
	# SAVED for jobs used to store a subset of a query
	STORED="STORED"
	
	before_destroy :remove_queued_job
	before_destroy :remove_experiment_association
	
	def remove_queued_job
		self.delayed_job.destroy unless self.delayed_job.nil?
	end
	
	def remove_experiment_association
		experiments = []
	end
	
	def self.all_without_data(ids = :all, opts = {})
		attr = LongJob.attribute_names.reject{|n| n == "result"}
		opts[:select] = attr
		ret = LongJob.find(ids, opts)
		ret = [ret] unless ret.is_a?(Array)
		ret
	end
	
	# == Description
	# This Job wraps a generic call to a function of an object and can handle callbacks
	class ProxyJob < Struct.new(:long_job_id, :obj, :method_name, :parameter)
		# Excuted before the job is processed. If calls the before-method on the object if the object responds to it
		def before(job)
			long_job = LongJob.find_by_delayed_job_id(job.id)
			d "[#{job.id}/#{long_job.id}{#{long_job.status}}] BEFORE"
			long_job.success = false
			long_job.started_at = Time.now
			long_job.error = "[BEFORE]#{long_job.error.to_s}\n\n#{job.last_error.to_s}"
			long_job.save!
			if (obj.respond_to?(:before)) then
				obj.send(:before, job)
			end
			ret = long_job.save!
			d "\t[#{long_job.id}{#{long_job.status}}] BEFORE"
			long_job = nil
			ret
		end
		
		# Executed the method on the object and stores the result
		def perform
			long_job = LongJob.find(long_job_id)
			d "[#{long_job.id}{#{long_job.status}}] PERFORM"
			if long_job.status != LongJob::FAILURE then
				long_job.status = LongJob::RUN
			end
			long_job.save!
			result =  obj.send(method_name.to_sym, *parameter)
			long_job.result = LongJob.marshal_and_zip(result) unless result.nil?
			#long_job.status = LongJob::DONE unless long_job.status == LongJob::FAILURE
			ret = long_job.save!
			d "\t[#{long_job.id}{#{long_job.status}}] PERFORM"
			long_job = nil
			# GC.start
			# ObjectSpace.garbage_collect
			ret
		end
		
		# Excuted after the job is processed. Calls the after-method on the object if the object responds to it
		def after(job)
			long_job = LongJob.find_by_delayed_job_id(job.id)
			d "[#{job.id}/#{long_job.id}{#{long_job.status}}] AFTER"
			raise "Job[#{job.id}] <#{job.to_s}> not found" if long_job.nil?
			if (obj.respond_to?(:after)) then
				long_job.save!
				obj.send(:after, job)
			end
			# long_job.status = LongJob::DONE unless long_job.status == LongJob::FAILURE
			# long_job.error = "#{long_job.error.to_s}\n\n#{job.last_error.to_s}" 
			ret = long_job.save!
			d "\t[#{long_job.id}{#{long_job.status}}] AFTER"
			long_job = nil
			GC.start
			ObjectSpace.garbage_collect
			ret
		end
		
		# Executed when the job was successful
		# TODO: This method is called even if the second attempt to process the job failed. This is why we must not reset the job status to SUCCESS if there was a FAILURE
		def success(job)
			long_job = LongJob.find_by_delayed_job_id(job.id)
			d "[#{job.id}/#{long_job.id}{#{long_job.status}}] SUCCESS"
			# if the job failed at least once mark it as failed.
			if long_job.status !=  LongJob::FAILURE then
				long_job.status = LongJob::DONE
				long_job.success = true
			end
			long_job.save!
			if (obj.respond_to?(:success)) then
				obj.send(:success, job)
			end
			long_job.finished_at = Time.now
			# long_job.error = "#{long_job.error.to_s}\n\n#{job.last_error.to_s}" 
			ret = long_job.save!
			d "\t[#{long_job.id}{#{long_job.status}}] SUCCESS"
			long_job = nil
			# GC.start
			# ObjectSpace.garbage_collect
			ret
		end
		
		# executed when there is an error, also stores the error message in the database
		# TODO: It should delete the failed job from the queue automatically
		def error(job, exception)
			long_job = LongJob.find_by_delayed_job_id(job.id)
			d "[#{job.id}/#{long_job.id}{#{long_job.status}}] ERROR"
			long_job.status = LongJob::FAILURE
			long_job.save!
			if (obj.respond_to?(:error)) then
				obj.send(:error, job, exception)
			end
			long_job.success = false
			delayed_job = DelayedJob.find(job.id)
			d exception
			d delayed_job.last_error
			long_job.error = "[ERROR]#{exception}\n\n#{long_job.error.to_s}\n\n#{delayed_job.last_error}\n\n#{exception.cause}"
			ret = long_job.save!
			d "\t[#{long_job.id}{#{long_job.status}}] ERROR"
			long_job = nil
			# GC.start
			# ObjectSpace.garbage_collect
			ret
		end
		
		# executed when there is a failure, also stores the error message in the database
		def failure()
			long_job = LongJob.find(long_job_id)
			d "[#{long_job.id}{#{long_job.status}}] FAILURE"
			long_job.status = LongJob::FAILURE
			long_job.save!
			if (obj.respond_to?(:failure)) then
				obj.send(:failure)
			end
			long_job.success = false
			delayed_job = DelayedJob.find(long_job.delayed_job_id)
			p delayed_job.last_error
			Rails.logger.error(delayed_job.last_error)
			long_job.error = "[FAILURE]#{long_job.error.to_s}\n\n#{delayed_job.last_error}"
			ret = long_job.save!
			d "\t[#{long_job.id}{#{long_job.status}}] FAILURE"
			Rails.logger.error("[#{long_job.id}{#{long_job.status}}] FAILURE")
			long_job = nil
			# GC.start
			# ObjectSpace.garbage_collect
			ret
		end
	
	end
	
	# returns the resul in JSON format
	def result_json()
		
		obj = LongJob.unzip_and_unmarshal(self.result)
		return [] if obj.nil?
		if not (obj.is_a?(Array) || obj.is_a?(Hash)) then
			obj = [obj]
		end
		
		return obj.to_json
	end
	
	def result_obj()
		LongJob.unzip_and_unmarshal(self.result)
	end
	
	# This function creates a ProxyJob object and enqueus it using DelayedJob
	# It takes three parameters
	# obj:: Instance of an object
	# method_name:: name of the method to be executed on the object
	# args*:: arbitrary number of arguments to pass to the method
	def run(obj, method_name, *args)
		@obj = obj
		@method_name = method_name
		@args = *args
		d "Creating DelayedJob for #{obj.to_s} -> #{method_name}(#{(args ||[]).join(",")})"
		self.status = LongJob::SETUP unless self.status == LongJob::FAILURE
		self.save!
		job_obj = ProxyJob.new(self.id, @obj, @method_name, args)
		@job = Delayed::Job.enqueue job_obj, queue: self.queue
		self.delayed_job_id = @job.id
		self.status = LongJob::ENQUEUE unless self.status == LongJob::FAILURE
		self.save!
		job_obj = nil
		# GC.start
		# ObjectSpace.garbage_collect
		return self
	end
	
	def redirect_to_job(params, action = "status")
		params_redirect = params.dup
		params_redirect[:controller] = "long_jobs"
		params_redirect[:action] = action
		params_redirect[:id] = self.id
		params_redirect
	end
	
	# generic functin to marshal and zip and object. This is used to save space in the database when results are cached.
	def self.marshal_and_zip(obj)
		mar = Marshal.dump(obj)
		comp = Zlib::Deflate.new(9).deflate(mar, Zlib::FINISH)
		mar = nil
		# GC.start
		# ObjectSpace.garbage_collect
		return comp
	end
	
	# see marshal_and_zip
	def self.unzip_and_unmarshal(data)
		return nil if data.nil?
		#Dir["#{Rails.root}/app/models/**/"].each do |dirname|
		#	Dir.new(dirname).to_a.each do |filename|
		#		next unless filename =~ /.rb$/
		#		model_name = File.basename(filename)
		#		#d "loading #{dirname + "/" + filename}"
		#		require_dependency dirname + "/" + filename
		#		# load dirname + "/" + filename
		#	end
		#end
		uncomp = Zlib::Inflate.new().inflate(data)
		# if the data contains an object that has not been autoloaded
		# Marshal.load will throw and ArgumentError: undefined class/module XXX
		# One source for this may be Aqua modules that create jobs with classes
		# that have not been used to far and are not auto loaded.
		# So we will just hail marry a Aqua._reload(true) in order to rescue the mess
		obj = nil
		begin
			obj = Marshal.load(uncomp)
		rescue ArgumentError => e
			
			Aqua._reload(true)
			begin
				obj = Marshal.load(uncomp)
			rescue NameError => f
				raise e
			end
		end
		uncomp = nil
		return obj
	end
	
	# Use this method to actually create and enqueue a job from outside of this class.
	# It handles the caching and returns either the newly created LongJob object, or the
	# LongJob object that was already cached.
	def self.create_job(attribs, use_cache = true, *args)
		if attribs[:title].to_s == "" then
			attribs[:title] = "No Description (#{attribs[:handle].class.to_s})"
		end
		checksum = generate_checksum(attribs[:handle], attribs[:method_name], args)
		
		result_is_known = false
		
		## check if it is in the cache and if the results are consistent.
		if use_cache then
			jobs = LongJob.where("checksum = ?", checksum)
			if jobs.size > 0 then
				## if all jobs with that checksum have the same result
				if jobs.all?{|j| j.result == jobs[0].result} then
					result_is_known = true
					long_job = jobs[0]
				else
					raise "The same input didn't yield the same output but you want to cache this now?! This is nuts and worth an exception!"
				end
			end
		end
		
		# create a new LongJob instance if neccessary
		if not result_is_known then
			attribs[:checksum] = checksum
			attribs[:parameter] = *args
			long_job = LongJob.new(attribs)
			long_job.save!
			long_job.run(attribs[:handle], attribs[:method], *args)
		end
		return long_job
	end
	
	private
	def self.generate_checksum(obj, method_name, args)
		objs = obj.to_yaml
		method_names = method_name.to_yaml
		argss = args.to_yaml.split("\n").sort.join("\n")
		
		Digest::MD5.hexdigest("#{objs}/#{method_names}/#{argss}")
	end
	
	def generate_checksum(obj, method_name, args)
		self.class.generate_checksum(obj, method_name, args)
	end

end
