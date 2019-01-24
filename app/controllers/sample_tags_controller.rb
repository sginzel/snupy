class SampleTagsController < ApplicationController
  before_filter :admin_required, :only => [ :new, :edit, :create, :delete, :destroy, :update ]
  
  # GET /sample_tags
  # GET /sample_tags.json
  def index
    @sample_tags = SampleTag.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @sample_tags }
    end
  end

  # GET /sample_tags/1
  # GET /sample_tags/1.json
  def show
    @sample_tag = SampleTag.find(params[:id])
		@samples = @sample_tag.samples
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @sample_tag }
    end
  end

  # GET /sample_tags/new
  # GET /sample_tags/new.json
  def new
    @sample_tag = SampleTag.new
    
		@samples = current_user.editable(Sample)
		
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @sample_tag }
    end
  end

  # GET /sample_tags/1/edit
  def edit
    @sample_tag = SampleTag.find(params[:id])
    @samples = current_user.editable(Sample)
  end

  # POST /sample_tags
  # POST /sample_tags.json
  def create
    @sample_tag = SampleTag.new(params[:sample_tag])
		
		@samples = Sample.find_all_by_id(params[:samples]) 
		@sample_tag.samples = @samples
		
    respond_to do |format|
      if @sample_tag.save
        format.html { redirect_to @sample_tag, notice: 'Sample tag was successfully created.' }
        format.json { render json: @sample_tag, status: :created, location: @sample_tag }
      else
        format.html { render action: "new" }
        format.json { render json: @sample_tag.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /sample_tags/1
  # PUT /sample_tags/1.json
  def update
    @sample_tag = SampleTag.find(params[:id])
    @samples = Sample.find_all_by_id(params[:samples])
		@sample_tag.samples = @samples

    respond_to do |format|
      if @sample_tag.update_attributes(params[:sample_tag])
        format.html { redirect_to @sample_tag, notice: 'Sample tag was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @sample_tag.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /sample_tags/1
  # DELETE /sample_tags/1.json
  def destroy
    @sample_tag = SampleTag.find(params[:id])
    @sample_tag.destroy

    respond_to do |format|
      format.html { redirect_to sample_tags_url }
      format.json { head :no_content }
    end
  end
end
