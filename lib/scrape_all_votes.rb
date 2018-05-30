require_relative 'voted'
require_relative 'get_mps'
require 'json'
require 'date'

class GetAllVotes
  UTF8_BOM = "\xEF\xBB\xBF".freeze
   def initialize
     $all_mp =  GetMp.new
   end
   def get_all_file

     uri = "http://opendata.city-adm.lviv.ua//api/3/action/package_search?fq=tags:%D0%B3%D0%BE%D0%BB%D0%BE%D1%81%D1%83%D0%B2%D0%B0%D0%BD%D0%BD%D1%8F&rows=100"
     json = open(uri).read
     hash_json = JSON.parse(json)
     p hash_json
     hash_json["result"]["results"].each do |res|
       p res["name"]
       res["resources"].each do |f|
         p f["url"]
         p f["last_modified"]
         #next if f["url"] == "http://opendata.city-adm.lviv.ua/dataset/254cc4ce-3721-4c20-a6cd-1a0e7f3e7329/resource/f4d4b5a9-6cda-4675-98a9-e35f70af8060/download/gol6p1.json"
         update = UpdatePar.first(url: f["url"], last_modified: f["last_modified"])
         if update.nil?
           read_file(f["url"] )
           UpdatePar.create!(url: f["url"], last_modified: f["last_modified"])
         end
       end
     end
   end
  def read_file(file)

    json = open(file).read

    my_hash = JSON.parse(json.force_encoding("UTF-8").gsub(/^#{UTF8_BOM}/, ''))
    p my_hash["GLTime"]

    date_caden = Date.strptime(my_hash["GLTime"].strip,'%d.%m.%Y')
    number = my_hash["PD_NPP"]
    p number
    date_vote = DateTime.strptime(my_hash["GLTime"].strip, '%d.%m.%Y %H:%M:%S')
    name = my_hash["PD_Fullname"]
    option = my_hash["RESULT"]
    rada_id = 6
    event = VoteEvent.first(name: name, date_vote: date_vote, number: number, date_caden: date_caden, rada_id: rada_id, option: option)
    if event.nil?
      events = VoteEvent.new(name: name, date_vote: date_vote, number: number, date_caden: date_caden, rada_id: rada_id, option: option)
      events.date_created = Date.today
      events.save
    else
      events = event
      events.votes.destroy!
    end
    my_hash["DPList"].each do |v|
      vote = events.votes.new
      vote.voter_id = $all_mp.serch_mp(v["DPName"].strip)
      vote.result =  short_voted_result(v["DPGolos"].upcase)
      vote.save
    end
  end
  def short_voted_result(result)
    hash = {
        "НЕ ГОЛОСУВАВ":  "not_voted",
        ВІДСУТНІЙ: "absent",
        ВІДСУТНЯ: "absent",
        ПРОТИ:  "against",
        ЗА: "aye",
        УТРИМАВСЯ: "abstain",
        УТРИМАЛАСЬ: "abstain"
    }
    hash[:"#{result.upcase}"]
  end
end
