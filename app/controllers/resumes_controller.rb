class ResumesController < ApplicationController
  # Skip authentication for now
  skip_before_action :authenticate_user!, raise: false
  
  def index
    @resumes = current_user.resumes if user_signed_in?
  end

  def create
    # Create a dummy user if not signed in
    user = user_signed_in? ? current_user : User.create!(
      email: "guest_#{Time.now.to_i}#{rand(100)}@example.com",
      password: SecureRandom.hex(10)
    )
    
    @resume = Resume.new(
      user: user,
      filename: resume_params[:file].original_filename,
      parsed_text: "Sample parsed text" # We'll just use a placeholder for now
    )

    # we get the job_title from the LLM/API

    if @resume.save
      text = ""
      reader = PDF::Reader.new(resume_params[:file].tempfile)
      reader.pages.each do |page|
        text << page.text
      end
      clean_text = text
                  .gsub(/\n+/, "\n")
                  .gsub(/[ \t]{2,}/, ' ')
                  .gsub(/\s+\n/, "\n")
                  .strip  
      job_title = get_job_title(clean_text)
      # binding.pry
      # Create a new search associated with this resume
      search = Search.create(user: user, resume: @resume, completed: false)
      
      # Start job fetching in a background thread
      Thread.new do
        # Find or create job type if provided
        job_type = nil
        
        # Use IndeedFetchJob to get job listings
        fetch_job = IndeedFetchJob.new(search.id, job_title)
        job_data = fetch_job.fetch_jobs
        
        # Save job details as search results
        job_data.each do |job|
          # Find or create job type
          if job[:job_type].present? && job[:job_type] != "Unknown"
            job_type = JobType.find_or_create_by(name: job[:job_type])
          end
          
          # Create the search result with all details
          search_result = search.search_results.create(
            title: job[:title],
            company: job[:company],
            location: job[:location],
            summary: job[:summary],
            description: job[:description],
            salary: job[:salary],
            work_setting: job[:work_setting],
            reference_number: job[:reference_number],
            url: job[:url]
          )
          
          # Associate job type if found
          if job_type && search_result.persisted?
            search.job_types << job_type unless search.job_types.include?(job_type)
          end
        end
        
        # Mark search as complete
        search.update(completed: true)
      end
      
      # Return the search ID for progress tracking
      render json: { 
        success: true, 
        search_id: search.id
      }
    else
      render json: { success: false, errors: @resume.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def job_progress
    search_id = params[:search_id]
    progress_file = "#{Rails.root}/tmp/job_progress_#{search_id}.json"
    
    if File.exist?(progress_file)
      progress = JSON.parse(File.read(progress_file))
      render json: progress
    else
      render json: { job_count: 0, total_target: 10, completed: false }
    end
  end
  
  def show
    search = Search.find_by(id: params[:id])
    
    if search
      search_results = search.search_results.to_a
      render json: {
        success: true,
        job_count: search_results.count,
        jobs: search_results,
        search_results: search_results
      }
    else
      render json: { success: false, error: "Search not found" }, status: :not_found
    end
  end

  private

  def resume_params
    params.require(:resume).permit(:file)
  end

  def get_job_title(text)
    api_key = ENV['OPENROUTER_API_KEY']
    response = HTTParty.post("https://openrouter.ai/api/v1/chat/completions",
      headers: {
        "Authorization" => "Bearer #{api_key}",
        "Content-Type" => "application/json"
      },
      body: {
        model: "mistralai/mistral-small", # or use "mistralai/mistral-7b-instruct"
        messages: [
          { role: "user", content: "Based on the resume text below, extract the most relevant programming-language-specific job title this person would most likely search for jobs under. Respond with only one word, such as 'Ruby', 'Python', 'React', etc. Avoid generic terms like 'Developer' or 'Engineer'. Resume Text: #{text}" }
        ],
        temperature: 0.2
      }.to_json
    )
    JSON.parse(response.body).dig("choices", 0, "message", "content")
  end
end
