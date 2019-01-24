module ToolsHelper

	def render_ppi_graph(edges, nodes, url_template, colors, groups, missing, opts = {})
		opts = {
			title: "SNuPy PPI Graph",
			id: "ppi_network_#{Time.now.to_f.to_s.gsub(".", "")}",
		}.merge(opts)

		
		render(partial: "tools/ppi_network_rendered", locals: {
			caption: "Rendered PPI Network",
			edges:edges,
			nodes:nodes,
			url_template: url_template,
			colors: colors,
			groups: groups,
			missing: missing
			}
		)
	end
	
end
