#!/usr/bin/env elixir

defmodule Server do
  def counter(scheduler) do
    send scheduler, {:ready, self}
    receive do
      {:count, file, client} ->
        send client, { :answer, file, word_count("cat", file), self }
        counter(scheduler)
      {:shutdown} ->
        exit(:normal)
    end
  end

  def word_count str, file do
    File.read!(file)
    |> String.split
    |> count_if(&(&1 == str))
  end
  def count_if list, f do
    _count_if list, f, 0
  end
  defp _count_if [], _f, tot do
    tot
  end
  defp _count_if [head | tail], f, tot do
    case f.(head) do
      true -> _count_if tail, f, tot + 1
      false -> _count_if tail, f, tot
    end
  end

end

defmodule Scheduler do
  def run(num_processes, module, func, to_calcuate) do
    (1..num_processes)
    |> Enum.map(fn(_) -> spawn(module, func, [self]) end)
    |> schedule_processes(to_calcuate, [])
  end
  defp schedule_processes(processes, queue, results) do
    receive do
      {:ready, pid} when length(queue) > 0 ->
        [ next | tail ] = queue
        send pid, {:count, next, self}
        schedule_processes(processes, tail, results)
      {:ready, pid} ->
        send pid, {:shutdown}
        if length(processes) > 1 do
          schedule_processes(List.delete(processes, pid), queue, results)
        else
          Enum.sort(results, fn {n1,_}, {n2,_} -> n1 <= n2 end)
        end
      {:answer, number, result, _pid} ->
        schedule_processes(processes, queue, [ {number, result} | results ])
    end
  end
end

:timer.tc(Scheduler, :run, [2, Server, :counter, File.ls!]) |> IO.inspect
