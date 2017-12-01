module Timed
  def timed
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    ended_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ((ended_at - started_at) * 1000).round
  end
end
