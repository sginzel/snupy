class AddRarityAndMotifInfoToVariationAnnotation < ActiveRecord::Migration
	def up
		add_column :variation_annotations, :has_consequence, :boolean, default: false ## GMAF as a double value
		add_column :variation_annotations, :global_pop_freq, :double, default: nil ## GMAF as a double value
		add_column :variation_annotations, :high_inf_pos, :boolean, default: false ## HIGH_INF_POS : A flag indicating if the variant falls in a high information position of a transcription factor binding profile
		add_column :variation_annotations, :motif_score_change, :double, default: 0 ## HIGH_INF_POS : A flag indicating if the variant falls in a high information position of a transcription factor binding profile
		
		add_index :variation_annotations, :global_pop_freq
		add_index :variation_annotations, :high_inf_pos
		add_index :variation_annotations, :motif_score_change
		add_index :variation_annotations, :has_consequence
		
		# set all VariationAnnotation object to have a consequence
		VariationAnnotation.transaction do
			VariationAnnotation.update_all(has_consequence: true)
		end
		
		## calculate global pop_freq for all VariationAnnotation objects
		num_obj = 0
		num_total = VariationAnnotation.where("gmaf IS NOT NULL").count
		update_buffer = []
		VariationAnnotation.where("gmaf IS NOT NULL")
		.joins(:alteration)
		.includes(:alteration)
		.select(["variation_annotations.id","variation_annotations.gmaf", "alterations.ref", "alterations.alt"])
		.find_in_batches do |vep_annots|
			vep_annots.each do |vepannot|
				num_obj += 1
				print("[UPDATE GLOBAL POP FREQ] #{num_obj}/#{num_total}\r") if num_obj % 100 == 1
				id = vepannot.id
				alt = vepannot.alteration.alt
				ref = vepannot.alteration.ref
				gmafs = [YAML.load(vepannot["gmaf"])].flatten
				pop_freq = []
				gmafs.each do |gmaf|
					allele, freq = gmaf.to_s.split(":")
					freq = freq.to_f
					if (allele == alt) then
						pop_freq << freq
					elsif (allele == "-" and (alt.length < ref.length)) # this happens for deletions
						pop_freq << freq
					elsif (allele.length > 1 and (alt.length > ref.length)) # this happens for insertions
						pop_freq << freq
					else
						pop_freq << (1-freq).round(4)
					end
				end
				pop_freq = pop_freq.min
				if !pop_freq.nil? then
					update_buffer << {freq: pop_freq, id: id}
				end
				if update_buffer.size > 1000 then
					VariationAnnotation.transaction do 
						update_buffer.each do |buffrec|
							ActiveRecord::Base.connection.execute("UPDATE #{VariationAnnotation.table_name} SET global_pop_freq = #{buffrec[:freq]} WHERE id = #{buffrec[:id]}")
						end
					end
					update_buffer = []
				end
			end
		end
		if update_buffer.size > 0 then
			VariationAnnotation.transaction do 
				update_buffer.each do |buffrec|
					ActiveRecord::Base.connection.execute("UPDATE #{VariationAnnotation.table_name} SET global_pop_freq = #{buffrec[:freq]} WHERE id = #{buffrec[:id]}")
				end
			end
		end
		print("[UPDATE GLOBAL POP FREQ] #{num_obj}/#{num_total} DONE \n") 
	end
	
	def down
		remove_index :variation_annotations, :global_pop_freq
		remove_index :variation_annotations, :high_inf_pos
		remove_index :variation_annotations, :motif_score_change
		remove_index :variation_annotations, :has_consequence
		
		remove_column :variation_annotations, :global_pop_freq
		remove_column :variation_annotations, :high_inf_pos
		remove_column :variation_annotations, :motif_score_change
		remove_column :variation_annotations, :has_consequence
		
	end
end
