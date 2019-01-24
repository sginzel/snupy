class VcfFileGatk < VcfFile
	def validate_vcf_header(header)
		raise "Not a valid GATK file." if !header.any?{|line| line.downcase.index("##gatkcommandline") || line.downcase.index("##unifiedgenotyper") }
	end
end

