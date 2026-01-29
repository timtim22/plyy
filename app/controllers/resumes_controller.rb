class ResumesController < ApplicationController
  # Skip authentication for now
  skip_before_action :authenticate_user!, raise: false
  
  def index
    @resumes = current_user.resumes if user_signed_in?
  end

  def create
    # Create a dummy user if not signed in
    user = user_signed_in? ? current_user : User.create!(
      email: "guest_#{Time.now.to_i}#{rand(1000)}@example.com",
      password: SecureRandom.hex(10)
    )
    
    # Create a dummy resume record
    @resume = Resume.create!(
      user: user,
      filename: resume_params[:file].original_filename,
      parsed_text: "DUMMY TEXT"
    )

    # Create a new search associated with this resume
    # We use created_at to track the fake progress
    search = Search.create!(user: user, resume: @resume, completed: false)
      
    # Return the search ID for progress tracking
    render json: { 
      success: true, 
      search_id: search.id
    }
  rescue => e
    render json: { success: false, errors: [e.message] }, status: :unprocessable_entity
  end
  
  def job_progress
    search = Search.find_by(id: params[:search_id])
    
    if search
      # Calculate progress based on time since creation
      # Run for about 5-8 seconds
      target_duration = 6.0 
      elapsed = Time.now - search.created_at
      
      if elapsed < target_duration
        # progress is proportional to time
        # limit to 9 jobs until complete
        fake_job_count = [(elapsed / target_duration * 10).to_i, 9].min
        render json: { job_count: fake_job_count, total_target: 10, completed: false }
      else
        search.update(completed: true) unless search.completed?
        render json: { job_count: 10, total_target: 10, completed: true }
      end
    else
       render json: { job_count: 0, total_target: 10, completed: false }
    end
  end
  
  def show
    # Just return dummy data
    dummy_jobs = [
      {
        title: "Senior Ruby Developer",
        company: "Tech Corp",
        location: "Remote",
        summary: "Great job working with Ruby and building scalable applications.",
        description: "Full description here...",
        salary: "$120k - $150k",
        work_setting: "Remote",
        url: "https://example.com/job1",
        job_type: "Full-time",
        reference_number: "REF-1234"
      },
      {
        title: "Rails Engineer",
        company: "Startup Inc",
        location: "New York, NY",
        summary: "Build cool things in a fast-paced environment.",
        description: "Full description...",
        salary: "$100k - $130k",
        work_setting: "Hybrid",
        url: "https://example.com/job2",
        job_type: "Full-time",
        reference_number: "REF-5678"
      },
       {
        title: "Backend Engineer",
        company: "Data Systems",
        location: "San Francisco, CA",
        summary: "Scale our systems and optimize database performance.",
        description: "Full description...",
        salary: "$140k - $180k",
        work_setting: "On-site",
        url: "https://example.com/job3",
        job_type: "Full-time",
        reference_number: "REF-9012"
      }
    ]
    
    render json: {
      success: true,
      job_count: dummy_jobs.count,
      jobs: dummy_jobs,
      search_results: dummy_jobs
    }
  end

  private

  def resume_params
    params.require(:resume).permit(:file)
  end
end
