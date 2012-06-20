require File.expand_path(File.dirname(__FILE__) + '/spec_helper_sinatra')

describe "primer_primer web interface" do
  include Rack::Test::Methods
  def app
    PrimerPrimer.init
    PrimerPrimer.new
  end

  it "should get '/' ok" do
    get '/'
    last_response.should be_ok
  end

  it "should return that there is no results when bad primers are given" do
    get 'primers/AAGCCACACACATAGACGTCAAAAAAAAATTTTT/CATGATCATGTGGGCGTTCT'
    last_response.body.should == "Sorry, no hits found."
  end

  it "should return positive results" do
    get 'primers/AAACTYAAAKGAATTGRCGG/ACGGGCGGTGWGTRC'
    last_response.should be_ok
    last_response.body.split("\n")[243].should == '      <node name="Microcoleus">'
    last_response.body.split("\n")[244].should == '       <magnitude><val>2</val></magnitude>'
  end

  it "should return correct negative results" do
    get '/primers/AAACTYAAAKGAATTGRCGG/ACGGGCGGTGWGTRC?negative=3'
    last_response.should be_ok
    last_response.body.split("\n")[54].should == '   <node name="4C0d-2 (hits 4/4)">'
  end
  
  it "should follow a redirect" do
    get '/primers', {:forward_primer => 'AAACTYAAAKGAATTGRCGG', :reverse_primer => 'ACGGGCGGTGWGTRC', :negative => '3'}
    follow_redirect!
    last_response.should be_ok
    last_response.body.split("\n")[54].should == '   <node name="4C0d-2 (hits 4/4)">'
  end
end
