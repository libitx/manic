defmodule Manic.Multi do
  @moduledoc """
  TODO
  """
  def test do
    token = "561b756d12572020ea9a104c3441b71790acbbce95a6ddbf7e0630971af9424b"
    [{:mempool, headers: [{"token", token}]}, :taal, :matterpool]
    |> Manic.multi(yield: :any)
    |> Manic.TX.status("7df417bf9d6f101adde8a1bcb707e1303b7e4c018d13563aaef11f537fd9e152")
  end


  defstruct miners: [],
            operation: nil,
            yield: :any


  @typedoc "TODO"
  @type t :: %__MODULE__{
    miners: list,
    operation: {atom, atom, list} | function,
    yield: :any | :all
  }

  @typedoc "TODO"
  @type result :: {:ok, Manic.miner, any} |
    [{term, {:error, Exception.t | String.t}}]


  @doc """
  TODO
  """
  def new(miners, options \\ []) when is_list(miners) do
    yield = Keyword.get(options, :yield, :any)
    struct(__MODULE__, [
      miners: miners,
      yield: yield
    ])
  end


  @doc """
  TODO
  """
  def async(%__MODULE__{} = multi, operation)
    when is_function(operation, 1),
    do: Map.put(multi, :operation, operation)
    
  def async(%__MODULE__{} = multi, module, function_name, args)
    when is_atom(module) and is_atom(function_name) and is_list(args),
    do: Map.put(multi, :operation, {module, function_name, args})


  @doc """
  TODO
  """
  def yield(multi, timeout \\ 5000)

  def yield(%__MODULE__{yield: :any} = multi, timeout) do
    parent = self()

    spawn_link(fn ->
      multi.miners
      |> Enum.map(& init_task(&1, multi.operation))
      |> yield_any(parent)
    end)

    receive do
      {key, result} ->
        {:ok, {key, result}}
      errors when is_list(errors) ->
        Enum.map(errors, fn {key, reason} -> {key, {:error, reason}} end)
    after
      timeout ->
        {:error, "Timeout"}
    end
  end

  def yield(%__MODULE__{yield: :all} = multi, timeout) do
    keyed_tasks = multi.miners
    |> Enum.map(& init_task(&1, multi.operation))

    keyed_tasks
    |> Enum.map(& elem(&1, 1))
    |> Task.yield_many(timeout)
    |> Enum.reduce([], fn {task, res}, results ->
      key = keyed_tasks
      |> Enum.find(fn {_key, t} -> task == t end)
      |> elem(0)
      case res do
        {:ok, res} -> [{key, res} | results]
        _ -> results
      end
    end)
    |> Enum.reverse
  end


  # TODO
  defp yield_any(tasks, parent, errors \\ [])

  defp yield_any(tasks, parent, errors)
    when length(tasks) > 0
    and is_pid(parent)
  do
    receive do
      {ref, {:ok, reply}} ->
        key = tasks
        |> Enum.find(fn {_key, task} -> task.ref == ref end)
        |> elem(0)
        send(parent, {key, reply})

      {ref, {:error, reason}} ->
        key = tasks
        |> Enum.find(fn {_key, task} -> task.ref == ref end)
        |> elem(0)
        tasks
        |> Enum.reject(fn {k, _task} -> k == key end)
        |> yield_any(parent, [{key, reason} | errors])

      {:DOWN, _ref, _, _pid, :normal} ->
        yield_any(tasks, parent, errors)

      {:DOWN, ref, _, _pid, reason} ->
        key = tasks
        |> Enum.find(fn {_key, task} -> task.ref == ref end)
        |> elem(0)
        tasks
        |> Enum.reject(fn {k, _task} -> k == key end)
        |> yield_any(parent, [{key, reason} | errors])

      msg ->
        IO.puts "Some other msg"
        IO.inspect msg
    end
  end

  defp yield_any([], parent, errors),
    do: send(parent, Enum.reverse(errors))


  # TODO
  defp init_task(%Tesla.Client{} = miner, operation) do
    Task.async(fn ->
      try do
        case operation do
          operation when is_function(operation, 1) ->
            apply(operation, [miner])
          {module, function_name, args} ->
            apply(module, function_name, [miner | args])
        end
      rescue
        error -> {:error, error}
      end
    end)
  end

  defp init_task({url, options} = key, operation) do
    task = Manic.miner(url, options)
    |> init_task(operation)
    {key, task}
  end

  defp init_task(url, operation) do
    task = Manic.miner(url)
    |> init_task(operation)
    {url, task}
  end
  
  
end