module StaticPagesHelper


    def code_snippet_installed?
        # check if code snippet on first webpage
        if @website_check[:error]
            return false
        elsif @website_check[:message].include?("graph.culturecreates.com")
            return true
        else
            return false
        end
    end

    def code_snippet_working?
        false
    end


end
