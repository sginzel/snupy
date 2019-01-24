class GenericListsController < ApplicationController
  # GET /generic_lists
  # GET /generic_lists.json
  def index
		@user = current_user
		if @user.is_admin then
			@generic_lists = GenericList.all
		else
			@generic_lists = @user.generic_lists
		end
    
		
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @generic_lists }
    end
  end

  # GET /generic_lists/1
  # GET /generic_lists/1.json
  def show
    @generic_list = GenericList.find(params[:id])
	@user = current_user
	
		
    respond_to do |format|
      format.html # show.html.erb
      format.json {
		  jsonpanel = @generic_list.attributes
		  jsonpanel["items"] = @generic_list.items
		  jsonpanel["genes"] = jsonpanel["items"].map{|x| x.value["gene"]}
		  render json: jsonpanel
	  }
    end
  end

  # GET /generic_lists/new
  # GET /generic_lists/new.json
  def new
    @generic_list = GenericList.new
		@user = current_user
		@users = User.all

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @generic_list }
    end
  end

  # GET /generic_lists/1/edit
  def edit
  	@generic_list = GenericList.find(params[:id])
  	@user = current_user
		@users = User.all
		
  end

  # POST /generic_lists
  # POST /generic_lists.json
  def create
  	type = params[:generic_list][:type]
  	allowed_lists = GenericList.available_lists.map(&:to_s)
  	if !allowed_lists.include?(params[:generic_list][:type]) then
  		raise "#{params[:generic_list][:type]} is not a valid list"
  	else
  		@generic_list = Kernel.const_get(params[:generic_list][:type].to_sym).new(params[:generic_list])
  	end
    #@generic_list = GenericList.new(params[:generic_list])
	@user = current_user
	@users = User.all
	@generic_list.users = User.find_all_by_id(params[:users])
 
	@generic_list.name = @generic_list.title.gsub(" ", "_").downcase if @generic_list.name.to_s == ""
	
	file = nil
	if !params[:file][:content].nil? && !params[:file][:content].tempfile.nil? then
		file = params[:file][:content].tempfile
	end

    respond_to do |format|
      if @generic_list.read_data({
      	 												data: params[:file][:data],
      													file: file, 
																idx: params[:file][:idx], 
																sep: params[:file][:sep],
																header: params[:file][:header].to_s == "1"}) &&
				@generic_list.save!
			then
        format.html { redirect_to @generic_list, notice: 'Generic list was successfully created.' }
        format.json { render json: @generic_list, status: :created, location: @generic_list }
      else
        format.html { render action: "new" }
        format.json { render json: @generic_list.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /generic_lists/1
  # PUT /generic_lists/1.json
  def update
    @generic_list = GenericList.find(params[:id])
    params_model_key = @generic_list.class.to_s.gsub(/([A-Z])/, "_\\1").gsub(/^_/, "").downcase.to_sym
		@user = current_user
		@users = User.all 
		@generic_list.users = User.find_all_by_id(params[:users])
		
		
		## delete all items if the List Type changed
		if params[params_model_key][:type] != @generic_list.type then
			@generic_list.items = []
		end

    respond_to do |format|
      if @generic_list.update_attributes(params[params_model_key])
      	success = true
      	file = nil
				if !params[:file][:content].nil? && !params[:file][:content].tempfile.nil? then
					file = params[:file][:content].tempfile
				end
				if !(file.nil? && params[:file][:data].nil?) then
					success = @generic_list.read_data({
																	data: params[:file][:data],
	      													file: file, 
																	idx: params[:file][:idx], 
																	sep: params[:file][:sep],
																	header: params[:file][:header].to_s == "1"})
				else
					if @generic_list.items.size == 0 then
						success = false
						@generic_list.errors[:base] << "no data or no file given"
					end
				end
				if success then
	        format.html { redirect_to @generic_list, notice: 'Generic list was successfully updated.' }
	        format.json { head :no_content }
				else
					format.html { render action: "edit" }
    			format.json { render json: @generic_list.errors, status: :unprocessable_entity }
				end
      else
        format.html { render action: "edit" }
        format.json { render json: @generic_list.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /generic_lists/1
  # DELETE /generic_lists/1.json
  def destroy
    @generic_list = GenericList.find(params[:id])
    @generic_list.destroy

    respond_to do |format|
      format.html { redirect_to generic_lists_url }
      format.json { head :no_content }
    end
  end
end
