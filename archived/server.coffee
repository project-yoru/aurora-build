# TODO Job Cleanup

kue = require 'kue'
queue = kue.createQueue()

build_web_online = ( data, done ) ->
  setTimeout ( -> done() ), 5000

Notifier =
  notify_job_completed: (job_id) ->
    # get the job
    kue.Job.get job_id, (err, job) ->
      throw err if err?
      console.log "Notifying web server the job is completed"

      distribution_id = job.data.distribution_id

      


queue.process 'build', (job, done) ->
  build_web_online job.data, done

queue
  .on 'job enqueue', (id, type) ->
    console.log "Job #{id} got queued of type #{type}"
  .on 'job complete', (id, result) ->
    console.log "Job #{id} completed with data: #{result}"
    Notifier.notify_job_completed id

    # TODO https://github.com/Automattic/kue/issues/843
    # kue.Job.get id, (err, job) ->
    #   # TODO handle err
    #   job.on 'complete', (result) ->
    #     console.log "Job completed with data: #{result}"

      # TODO handle `failed attempt`, `failed`, `progress` events

kue.app.listen 4000
