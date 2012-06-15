#!/usr/bin/env ruby
#
# PrimerPrimer
# Author:: Ben J. Woodcroft
# Copyright:: 2012

require 'sinatra'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'bioruby-krona','lib'))
require 'bio-krona'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'bioruby-ipcress','lib'))
require 'bio-ipcress'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'amplicon_encyclopaedia','lib'))
require 'amplicon_encyclopaedia'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'bioruby-sra','lib'))
require 'bio-sra'

class PrimerPrimer < Sinatra::Base
  def cache_greengenes
    if @greengenes_otu_ids_to_species.nil?
      #work out the background distributions for all of the different species
      @greengenes_otu_ids_to_species = {}
      $stderr.print "Caching greengenes background..."
      File.open('/home/ben/mnt/hawke_gut/srv/whitlam/bio/db/gg/qiime_default/gg_otus_4feb2011/taxonomies/greengenes_tax.txt').each_line do |line|
        splits = line.split("\t")
        raise unless splits.length == 2
        taxon = splits[1].split(';').collect do |lineage_string|
          lineage_string.gsub(/^.__/,'')
        end
        @greengenes_otu_ids_to_species[splits[0].to_i] = taxon
      end
      @background_greengenes_hash = {}
      @greengenes_otu_ids_to_species.each do |otu_id, lineage|
        @background_greengenes_hash[lineage] = 1
      end
      $stderr.puts 'done'
    end
  end

  def cache_amplicon_encyclopaedia
    $stderr.print "Caching amplicon encyclopaedia..."
    @amplicon_encyclopaedia = AmpliconEncyclopaedia::CSVDatabase.new.publications_hash
    $stderr.puts 'done'
  end

  get '/' do
    redirect '/greengenes'
  end

  get '/greengenes' do
    cache_greengenes
    Bio::Krona.html(@background_greengenes_hash)
  end

  get '/sra/:sra_id' do
  # Do we have this SRA identifier?
    @accession = params[:sra_id]
    Bio::SRA.connect
    @runs = Bio::SRA::Tables::SRA.accession(params[:sra_id]).all
    if @runs.empty?
      "Sorry, I'm unable to find accession #{params[:sra_id]} in the SRA database"
    else
    # Try to find if this entry has been curated into the amplicon encyclopaedia
      cache_amplicon_encyclopaedia
      @all_sra_accession_numbers = @runs.collect do |sra|
        [sra.submission_accession, sra.study_accession, sra.sample_accession, sra.experiment_accession, sra.run_accession]
      end.flatten.uniq

      @ae_publications = @amplicon_encyclopaedia.select_by_accessions(@all_sra_accession_numbers)
      erb :sra
    end
  end

  get '/:forward_primer/:reverse_primer' do
    acceptable_hits = {}
    cache_greengenes

    # Run this primer set against all greengenes otus
    primer_set = Bio::Ipcress::PrimerSet.new(params[:forward_primer],params[:reverse_primer])
    gg_fasta = '/home/ben/mnt/hawke_gut/srv/whitlam/bio/db/gg/qiime_default/gg_otus_4feb2011/rep_set/gg_94_otus_4feb2011.fasta'
    ipcress_hits = Bio::Ipcress.run(primer_set, gg_fasta, :mismatches => 2)

    $stderr.puts "Found #{ipcress_hits.length} hits with ipcress"
    ipcress_hits.each do |ipcress|
      mismatches2 = ipcress.recalculate_mismatches_from_alignments
      if mismatches2[0] == 0 and mismatches2[1] == 0
        gg_id = ipcress.target.gsub(/:.*/,'').to_i
      lineage = @greengenes_otu_ids_to_species[gg_id]
      acceptable_hits[lineage] = 1
      end
    end
    
    if !params[:negative]
      Bio::Krona.html(acceptable_hits)
    else
      max_levels = params[:negative].to_i
      
      # create a negative hash by copying the greengenes hash deeply and then setting acceptable hits to 0 in that hash
      negative_hash = @background_greengenes_hash.clone
      acceptable_hits.each do |lineage, count|
        negative_hash[lineage] = 0
      end
      
      # collapse the greengenes hash
      gg_collapsed = Bio::Krona.collapse(@background_greengenes_hash, max_levels)
      
      # collapse the acceptable hash
      acceptable_collapsed = Bio::Krona.collapse(acceptable_hits, max_levels)
      
      # normalise the negative hash in the background of the greengenes hash
      negative_collapsed = {}
      gg_collapsed.keys.each do |lineage|
        acceptables = acceptable_collapsed[lineage]
        acceptables ||= 0
        num_negative = gg_collapsed[lineage].to_f-acceptables
        negative_collapsed[lineage] = (num_negative+1)/(acceptables+1)
        # impose a zero minimum, otherwise that is just confusing
        negative_collapsed[lineage] = 0 if negative_collapsed[lineage]<0
      end
      Bio::Krona.html(negative_collapsed)
    end
      
  end
end