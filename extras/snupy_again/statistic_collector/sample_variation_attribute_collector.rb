module SnupyAgain
	module StatisticCollector
		class SampleVariationAttributeCollector < SnupyAgain::StatisticCollector::Template
			# collects statistics about transition/transversion ratio
			# amino acid substitution matrix -> using VEP
			# heterozygous/homozygous ratio
			def do_collect()
				sample = @object
				stats = {
					id: sample.id,
					nickname: sample.nickname,
					name: sample.name,
					specimen: (sample.specimen_probe || SpecimenProbe.new).name,
					entity: (sample.entity || Entity.new).name,
					entity_group: (sample.entity_group || EntityGroup.new).name
				}
				## count total number of variations
				# stats["Tr/Tv"] = get_trtv(sample)
				stats = stats.merge(get_trtv(sample))
				# stats["AA-substitution"] = get_aasub(sample)
				stats["Het/Hom ratio"] = get_hethom(sample)
				stats = stats.merge(get_onofftarget(sample))

				tbl = [stats]
				tag = SampleStatistic.new(
					sample_id: sample.id,
					name: "SampleVariationProperties",
					resource: self.class.name,
					value: tbl.to_yaml,
					plotstyle: "table"
				)
				tag
			end

			# transition     / transversion
			# (A<->G + C<->T)/(A<->C+A<->T+G<->C+G<->T)
			def get_trtv(sample)
				# find alteration ids for transition and trasversions
				trstatement = [["A", "G"], ["C", "T"]].map{|a1,a2| sprintf("((ref = '%s' AND alt = '%s') OR (ref = '%s' AND alt = '%s') )", a1, a2, a2, a1)}.join(" OR ")
				tvstatement = [["A", "C"], ["A", "T"], ["G", "C"], ["G", "T"]].map{|a1,a2| sprintf("((ref = '%s' AND alt = '%s') OR (ref = '%s' AND alt = '%s') )", a1, a2, a2, a1)}.join(" OR ")
				trids = Alteration.where(trstatement).pluck(:id)
				tvids = Alteration.where(tvstatement).pluck(:id)

				trcount = sample.variation_calls.where(filter: "PASS").joins(:alteration).where("alterations.id" => trids).count(:variation_id, distinct: true).to_f
				tvcount = sample.variation_calls.where(filter: "PASS").joins(:alteration).where("alterations.id" => tvids).count(:variation_id, distinct: true).to_f

				{
						"Tr/Tv" => (trcount/tvcount),
						"#Tr" => trcount,
						"#Tv" => tvcount
				}

			end

			# use deviation from BLOSUM matrix
			def get_aasub(sample)
				raise("NOT implemented")
			end

			def get_hethom(sample)
				num_total = sample.variation_calls.where(filter: "PASS").count(:variation_id, distinct: true).to_f
				num_hom = sample.variation_calls.where(gt: ["1/1", "1|1"], filter: "PASS").count(:variation_id, distinct: true).to_f

				((num_total-num_hom)/num_hom).round(3)
			end

			def get_onofftarget(sample)
				ret = {
						"Notice" => "CaptureKit file module not available."
				}
				if (defined?CaptureKitFile and defined?CaptureKit and defined?CaptureKitAnnotation) then
					return ret if sample.vcf_file.nil?
					return ret if sample.vcf_file.aqua_annotation_status([CaptureKitAnnotation]).nil?
					return ret unless sample.vcf_file.aqua_annotation_status([CaptureKitAnnotation]).first.is_complete?
					num_total = sample.variation_calls.where(filter: "PASS").count(:variation_id, distinct: true).to_f
					num_total = 0.0 if num_total.nil?
					# exome_capture_kits = CaptureKitFile.where(capture_type: "exome_capture").pluck(:id)
					exome_capture_kits = CaptureKitFile.where(capture_type: "exome_capture")
														.where(organism_id: sample.vcf_file.organism_id)
						                                .select([:id, :name])
					ret = {
						num_total: num_total#,
						#num_on_target: num_on_target,
						#num_off_target: num_off_target,
						#off_target_ratio: ratio
					}
					exome_capture_kits.each do |exome_capture_kit|
						num_on_target = CaptureKit.where("variation_id IN (SELECT variation_id FROM variation_calls WHERE sample_id = #{sample.id} AND filter = 'PASS' ORDER BY variation_id)")
																			.where(organism_id: sample.vcf_file.organism_id)
																			.where(capture_kit_file_id: exome_capture_kit)
																			.where('dist = 0')
																			.count(:variation_id, distinct: true).to_f
						num_on_target = 0.0 if num_on_target.nil?
						num_off_target = num_total - num_on_target
						ratio = nil
						ratio = (num_off_target/num_total).round(3) if num_total > 0
						ret.merge!({
							"on_target_#{exome_capture_kit.name.gsub(" ", "_")}" => num_on_target,
							"off_target_#{exome_capture_kit.name.gsub(" ", "_")}" => num_off_target,
							"off_target_ratio_#{exome_capture_kit.name.gsub(" ", "_")}" => ratio
						})
					end
					
					ret
				end
				ret
			end

			attr_collectable :sample 
			
		end
	end
end