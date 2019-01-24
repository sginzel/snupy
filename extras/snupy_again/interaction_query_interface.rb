module SnupyAgain
	module InteractionQueryInterface
		class StringRemoteQueryInterface
			
			require "net/http"
			
			MAPPINGURL = "http://string-db.org/api/tsv-no-header/resolveList?identifiers=%s&format=only-ids"
			# INTERACTIONURL = "http://string-db.org/api/tsv/interactionsList?identifiers=%s&required_score=%d"
			INTERACTIONURL = "http://string-db.org/api/psi-mi-tab/interactionsList?identifiers=%s&required_score=%d&limit=100"
			
			def initialize(species = 9606, score = 600)
				@species = species
				@score = score
			end
			
			def query_interactions(geneids)
				geneids = geneids.keys if geneids.is_a?(Hash)
				geneids = [geneids] unless geneids.is_a?(Array)
				
				stringids = get_stringids(geneids)
				interactors = []
				interactors = get_interactors(stringids) if stringids.size > 0
				return interactors
			end
			
			def get_stringids(geneids)
				url = URI.parse(sprintf(MAPPINGURL, geneids.join("%0D")))
				begin
				   data = Net::HTTP.get_response(url).body
				rescue
				   print "Connection error."
				end
				data = data.split("\n")
				data.select!{|stringid| stringid =~ /^#{@species}./ }
				data
			end
			
			def get_interactors(stringids)
				url = URI.parse(sprintf(INTERACTIONURL, stringids.join("%0D"), @score))
				begin
				   data = Net::HTTP.get_response(url).body
				rescue
				   print "Connection error."
				end
				data = data.split("\n").map{|row| 
					row = row.split("\t")
					score = (row[-1].split("|")[0] || "0:0").split(":")[1]
					[row[0], row[1], row[2], row[3], score]
				}
				ret = []
				header = %w(stringid1 stringid2 symbol1 symbol2 score)
				ret = data.map{|rec|
					ret = Hash[header.each_with_index.map{|h, i| [h, rec[i]] }]
					ret["ensp1"] = ret["stringid1"].split(".")[1]
					ret["ensp2"] = ret["stringid2"].split(".")[1]
					ret
				}
				ret.uniq
			end
			
		end
	end
end