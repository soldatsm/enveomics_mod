#!/usr/bin/env ruby
#
# @author Luis M. Rodriguez-R
# @update Oct-21-2015
# @license artistic license 2.0
#

$:.push File.expand_path("lib", File.dirname(__FILE__))
require "enveomics_rb/enveomics"
require "enveomics_rb/og"

o = {q:false, pergenome:false, prefix:false, first:false, core:0.0, dups:0}
OptionParser.new do |opts|
   opts.banner = "
Extracts sequences of Orthology Groups (OGs) from genomes (proteomes).

Usage: #{$0} [options]"
   opts.separator ""
   opts.separator "Mandatory"
   opts.on("-i", "--in FILE",
      "Input file containing the OGs (as generated by ogs.rb)."){ |v| o[:in]=v }
   opts.on("-o", "--out FILE",
      "Output directory where to place extracted sequences."){ |v| o[:out]=v }
   opts.on("-s", "--seqs STRING",
      "Path to the proteomes in FastA format, using '%s' to denote the genome.",
      "For example: /path/to/seqs/%s.faa."){ |v| o[:seqs]=v }
   opts.separator ""
   opts.separator "Other Options"
   opts.on("-c", "--core FLOAT",
      "Use only OGs present in at least this fraction of the genomes.",
      "To use only the strict core genome*, use -c 1."){ |v| o[:core]=v.to_f }
   opts.on("-d", "--duplicates INT",
      "Use only OGs with less than this number of in-paralogs in a genome.",
      "To use only genes without in-paralogs*, use -d 1."
      ){ |v| o[:dups]=v.to_i }
   opts.on("-g", "--per-genome",
      "If set, the output is generated per genome.",
      "By default, the output is per OG."){ |v| o[:pergenome]=v }
   opts.on("-p", "--prefix",
      "If set, each sequence is prefixed with the genome name",
      "(or OG number, if --per-genome) and a dash."){ |v| o[:prefix]=v }
   opts.on("-f", "--first",
      "Get only one gene per genome per OG (first) regardless of in-paralogs.",
      "By default all genes are extracted."){ |v| o[:first]=v }
   opts.on("-q", "--quiet", "Run quietly (no STDERR output)."){ o[:q] = TRUE }
   opts.on("-h", "--help", "Display this screen.") do
      puts opts
      exit
   end
   opts.separator ""
   opts.separator "    * To use only the unus genome (OGs with exactly one " +
      "gene per genome), use: -c 1 -d 1."
   opts.separator ""
end.parse!
abort "-i is mandatory" if o[:in].nil?
abort "-o is mandatory" if o[:out].nil?
abort "-s is mandatory" if o[:seqs].nil?

##### MAIN:
begin
   # Read the pre-computed OGs
   collection = OGCollection.new
   $stderr.puts "Reading pre-computed OGs in '#{o[:in]}'." unless o[:q]
   f = File.open(o[:in], "r")
   h = f.gets.chomp.split /\t/
   while ln = f.gets
      collection << OG.new(h, ln.chomp.split(/\t/))
   end
   f.close
   $stderr.puts " Loaded OGs: #{collection.ogs.size}." unless o[:q]
   $stderr.puts " Reported Genomes: #{Gene.genomes.size}." unless o[:q]

   # Filter core/in-paralog genes
   collection.filter_core! o[:core] unless o[:core]==0.0
   collection.remove_inparalogs! o[:dups] unless o[:dups]==0
   $stderr.puts " Filtered OGs: #{collection.ogs.size}." unless
      o[:q] or o[:core]==0.0

   # Open outputs
   $stderr.puts "Initializing output files." unless o[:q]
   Dir.mkdir(o[:out]) unless Dir.exist? o[:out]
   ofhs = o[:pergenome] ?
      Gene.genomes.map{|g| File.open("#{o[:out]}/#{g}.fa", "w")} :
      ( (1 .. collection.ogs.size).map do |og|
	 File.open("#{o[:out]}/OG#{og}.fa", "w")
      end )
   $stderr.puts " Created files: #{ofhs.size}." unless o[:q]
   
   # Read genomes
   $stderr.puts "Filtering genes." unless o[:q]
   genome_i = -1
   Gene.genomes.each do |genome|
      genome_i = Gene.genomes.index(genome)
      $stderr.print "  Genome #{genome_i+1}.   \r" unless o[:q]
      genes = ( collection.get_genome_genes(genome).map do |og|
	    o[:first] ? [og.first] : og
	 end )
      hand = nil
      File.open(sprintf(o[:seqs], genome), "r").each do |ln|
	 if ln =~ /^>(\S+)/
	    og = genes.index{|g| g.include? $1}
	    hand = og.nil? ? nil : ( o[:pergenome] ? genome_i : og )
	    ln.sub!(/^>/, ">#{o[:pergenome] ? "OG#{og}" : genome}-") if
	       o[:prefix] and not hand.nil?
	 end
	 ofhs[hand].puts(ln) unless hand.nil?
      end
   end
   $stderr.puts "  #{genome_i+1} genomes processed." unless o[:q]

   # Close outputs
   $stderr.puts "Closing output files." unless o[:q]
   ofhs.each{|h| h.close}
   $stderr.puts "Done.\n" unless o[:q] 
rescue => err
   $stderr.puts "Exception: #{err}\n\n"
   err.backtrace.each { |l| $stderr.puts l + "\n" }
   err
end


