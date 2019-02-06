require 'uri'
require 'net/http'
require 'json'

class AdviseHooks < Redmine::Hook::ViewListener
    def view_layouts_base_html_head(context)
        stylesheet_link_tag 'endline.css', :plugin => 'advise'
    end
    
    def controller_issues_new_after_save(context)
        begin
            if !Project.find(context[:issue][:project_id]).enabled_module('advise')
                return nil
            end

            user = User.find_by_login("tma_advisor")
            if !user
                user = User.new(
                    :login => "tma_advisor", 
                    :firstname => "TMA", 
                    :lastname => "Advisor", 
                    :generate_password => true,
                    :mail => "tma-advisor@alterway.fr")
                user.save()
            end
            
            response = post(
                Setting.plugin_advise['url'],
                JSON.generate({
                    :content => context[:issue][:subject] + " " + context[:issue][:description],
                    :ticketId => context[:issue][:id],
                    :project => Project.find(context[:issue][:project_id]).name,
                    :treshold => Setting.plugin_advise['treshold'],
                    :count => Setting.plugin_advise['count']
                })
            )
            
            if(response["closest"])
                notes = "-- Redmine Advise --\n"
                notes << "\nTicket le plus ressemblant:\n"
                notes << "id | autheur | commun% | date | titre \n"
                notes << toDetails(response["closest"])
                notes << "\nTickets les proches du même projet:\n"
                notes << "id | autheur | commun% | date | titre \n"
                notes << (response["project_closests"].map {|x| toDetails(x)}).join("")
                
                j = Journal.new(
                    :journalized => Issue.find(context[:issue][:id]),
                    :user => user,
                    :notes => notes,
                    :private_notes => true,
                    :details => [JournalDetail.new(:property => 'relation', :prop_key => 'relates')])
                j.save()
            end
            
        rescue Exception => e
            Rails.logger.error "ADVISE_PLUGIN ERROR: #{e}"
        end
    end

    def post(url, body)
        uri = URI.parse(URI.encode(url))
        request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
        request.body = body
        
        response = Net::HTTP.start(uri.host, uri.port, 
            :use_ssl => uri.scheme == 'https', 
            :open_timeout => 2, 
            :read_timeout => 2) do |http|

            http.request(request)
        end
        
        return JSON.parse(response.body)
    end

    def toDetails(advise)
        begin
            ticket = Issue.find(advise["id"])
            correlation = (100 * (1 - advise["distance"])).round
            username = User.find(ticket[:author_id]).to_s || 'anonymous'
        
            return "#" + advise["id"].to_s + "  | " + username + " | " + correlation.to_s + " | " + ticket[:start_date].to_s + " | " + ticket[:subject].to_s + " \n"
        rescue
            Rails.logger.error "ADVISE_PLUGIN WARN: could'nt find issue ##{advise["id"].to_s}"
            return ""
        end
    end
end
