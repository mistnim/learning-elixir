#!/usr/bin/env elixir

defmodule BarberShop do
  def barber ca_pid do
    send ca_pid, {:ready, self}
    _barber ca_pid
  end
  defp _barber ca_pid do
    receive do
      :sleep ->
        IO.puts "Barber: There are no clients, I go to sleep."
        _barber ca_pid
      {:cut, pid, mane} ->
        IO.puts "barber: I'm cutting #{inspect pid}'s hairs'"
        :timer.sleep 200 * mane
        send pid, :done
        send ca_pid, :ready
        _barber ca_pid
    end
  end

  def client_spawner ca_pid do
    (:rand.uniform * 1800) |> Float.floor |> round
    |> :timer.sleep
    mane = (:rand.uniform * 10) |> Float.floor |> round
    spawn BarberShop, :client, [ca_pid, mane]
    client_spawner ca_pid
  end

  def client ca_pid, mane do
    send ca_pid, {:sit, self}
    receive do
      {:go, bpid} ->
        client_send bpid, mane
      :full ->
        IO.puts "#{inspect self}: There is no place, goodbye."
      :sit ->
        IO.puts "#{inspect self}: Ok, I'll sit and wait"
        receive do
          {:go, bpid} ->
            client_send bpid, mane
        end
    end
  end
  defp client_send bpid, mane do
    send bpid, {:cut, self, mane}
    receive do
      :done -> exit :normal
    end
  end

  def chairs_agent max_size do
    receive do
      {:ready, pid} ->
      _chairs_agent pid, {:ready, 0, max_size, :queue.new}
    end
  end
  defp _chairs_agent barber_pid, state = {barber_status, size, max_size, queue} do
    receive do
      :ready ->
        if size == 0 do
          send barber_pid, :sleep
          _chairs_agent barber_pid, {:ready, size, max_size, queue}
        else
          {{:value, pid}, new_queue} = :queue.out queue
          send pid, {:go, barber_pid}
          _chairs_agent barber_pid, {:not_ready, size - 1, max_size, new_queue}
        end

      {:sit, pid} ->
        case state do
          {:ready, 0, _, _} ->
            send pid, {:go, barber_pid}
            _chairs_agent barber_pid, {:not_ready, size, max_size, queue}
          {_, ^max_size, _, _} ->
            send pid, :full
            _chairs_agent barber_pid, state
          _ ->
            send pid, :sit
            _chairs_agent barber_pid, {barber_status, size + 1, max_size, :queue.in(pid, queue)}
        end
    end
  end
end

pid = spawn BarberShop, :chairs_agent, [10]
spawn BarberShop, :barber, [pid]
spawn BarberShop, :client_spawner, [pid]

receive do
end
