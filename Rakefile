namespace :db do
  desc 'Clear embeddings and reset documents'
  task :clear_embeddings do
    puts "Clearing embeddings..."
    Embedding.delete_all
    RawDocument.update_all(processed: false)
    puts "Embeddings cleared and documents reset"
  end

  desc 'Show database stats'
  task :stats do
    total_docs = RawDocument.count
    processed_docs = RawDocument.processed.count
    total_embeddings = Embedding.count

    puts "\nDatabase Stats:"
    puts "Total Documents: #{total_docs}"
    puts "Processed Documents: #{processed_docs}"
    puts "Total Embeddings: #{total_embeddings}"
    puts "\nProgress: #{processed_docs}/#{total_docs} documents processed (#{(processed_docs.to_f / total_docs * 100).round(2)}%)"
  end
end
