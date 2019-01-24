# This migration can only be run after the tags were added.
# That is because the associations between vcf files and tags was added later in the development.
class UpdateVcfAndSampleFilter < ActiveRecord::Migration
  def up
    # for some reason we need to reset the column information so filters can acutalle be set here.
    VcfFile.connection.schema_cache.clear!
    VcfFile.reset_column_information
    Sample.reset_column_information
    VcfFile.all.each do |vcf|
      vcf.filters = vcf.get_filter_values_from_content
      vcf.filters
      vcf.save!
    end
    # build cache with all vcf_ids and their filters, so content is not loaded for all vcf files
    # when iterating over all samples
    vcffilters = {}
    VcfFile.select([:id, :filters]).each do |vcf|
      vcffilters[vcf.id] = YAML.load(vcf.filters)
    end
    Sample.all.each do |smpl|
      if smpl.ignorefilter then # if ignorefilter is set use all availble vcf filters...
        smpl.filters = vcffilters[smpl.vcf_file_id].keys.sort.join(",")
      else
        smpl.filters = ["PASS"].sort.join(",")
      end
      smpl.save!
    end
  end

  def down
  end
end
