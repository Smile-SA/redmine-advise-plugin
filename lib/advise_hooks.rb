require 'uri'
require 'net/http'
require 'json'

class AdviseHooks < Redmine::Hook::ViewListener
    def controller_issues_new_after_save(context)
        begin
            if !Project.find(context[:issue][:project_id]).enabled_module('advise')
                return nil
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
                notes << "Ticket le plus ressemblant: "
                notes << toLink(response["closest"])
                notes << "\n"
                notes << "Tickets les proches du même projet: "
                notes << (response["project_closests"].map {|x| toLink(x)}).join(" ")

                j = Journal.new(
                    :journalized => Issue.find(context[:issue][:id]),
                    :user => User.anonymous,
                    :notes => notes,
                    :details => [JournalDetail.new(:property => 'relation', :prop_key => 'relates')])
                j.save()
            end
            
        rescue => exception
            print exception
        end
    end

    def post(url, body)
        uri = URI(url)
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

    def toLink(ticketId)
        return "#" + ticketId.to_s
    end
end
