class QueryDigenic < ComplexQuery
	register_query :digenic,
				   label: 'Digenic association',
				   default: %w(dida),
				   type: :collection,
				   combine: 'AND',
				   tooltip: 'Checks if a specimen has hits in two genes of a digenic database.',
				   organism: [organisms(:human), organisms(:mouse)],
				   priority: 80
end