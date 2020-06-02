defmodule Manic.Multi do
  @moduledoc """
  Module for encapsulating multiple miner Merchant API clients.
  """
  alias Manic.Miner


  defstruct miners: [],
            operation: nil,
            yield: :any,
            timeout: 5_000


  @typedoc "Bitcoin multi miner API client"
  @type t :: %__MODULE__{
    miners: list,
    operation: {atom, atom, list} | function,
    yield: :any | :all
  }

  @typedoc "Multi miner API response"
  @type result :: {Manic.miner, {:ok, any}} |
    [{Manic.miner, {:ok | :error, any}}, ...]


  @doc """
  Returns a [`multi miner`](`t:t/0`) client for the given list of
  Merchant API endpoints.
  """
  @spec new(list, keyword) :: __MODULE__.t
  def new(miners, options \\ []) when is_list(miners) do
    yield = Keyword.get(options, :yield, :any)
    struct(__MODULE__, [
      miners: Enum.map(miners, &Miner.new/1),
      yield: yield
    ])
  end


  @doc """
  Sets the asynchronous operation on the given [`multi miner`](`t:t/0`)
  client.

  The operation is an inline function which receives the [`miner`](`t:Manic.miner/0`)
  client.

  ## Example

      iex> Manic.Multi.async(multi, fn miner ->
      ...>   MyModule.some_function(miner)
      ...> end)

  Or, the same more succinctly:

      iex> Manic.Multi.async(multi, &MyModule.some_function/1)
  """
  @spec async(__MODULE__.t, function) :: __MODULE__.t
  def async(%__MODULE__{} = multi, operation)
    when is_function(operation, 1),
    do: Map.put(multi, :operation, operation)


  @doc """
  Sets the asynchronous operation on the given [`multi miner`](`t:t/0`)
  client.

  The operation is passed as a tuple containing the module, function name and
  list or arguments. In this case, the [`miner`](`t:Manic.miner/0`) client will
  automatically be prepended to the list of arguments.

  ## Example

      iex> Manic.Multi.async(multi, MyModule, :some_function, args)
  """
  @spec async(__MODULE__.t, atom, atom, list) :: __MODULE__.t
  def async(%__MODULE__{} = multi, module, function_name, args)
    when is_atom(module) and is_atom(function_name) and is_list(args),
    do: Map.put(multi, :operation, {module, function_name, args})


  @doc """
  Concurrently runs the asynchronous operation on the given [`multi miner`](`t:t/0`)
  client, yielding the response from any or all of the miners.

  By default, multi miner operations will yield until **any** of the miners
  respond. Alternatively, a multi client can be initialized with the option
  `yield: :all` which awaits for **all** miner clients to respond.
  """
  @spec yield(__MODULE__.t) :: result
  def yield(%__MODULE__{yield: :any, timeout: timeout} = multi) do
    parent = self()

    spawn_link(fn ->
      multi.miners
      |> Enum.map(& init_task(&1, multi.operation))
      |> yield_any(parent)
    end)

    receive do
      {miner, result} ->
        {miner, {:ok, result}}
      errors when is_list(errors) ->
        Enum.map(errors, fn {miner, reason} -> {miner, {:error, reason}} end)
    after
      timeout ->
        {:error, "Timeout"}
    end
  end

  def yield(%__MODULE__{yield: :all, timeout: timeout} = multi) do
    keyed_tasks = multi.miners
    |> Enum.map(& init_task(&1, multi.operation))

    keyed_tasks
    |> Enum.map(& elem(&1, 1))
    |> Task.yield_many(timeout)
    |> Enum.reduce([], fn {task, res}, results ->
      miner = keyed_tasks
      |> Enum.find(fn {_miner, t} -> task == t end)
      |> elem(0)
      case res do
        {:ok, res} -> [{miner, res} | results]
        _ -> results
      end
    end)
    |> Enum.reverse
  end


  # Yields until any miner client responds
  defp yield_any(tasks, parent, errors \\ [])

  defp yield_any(tasks, parent, errors)
    when length(tasks) > 0
    and is_pid(parent)
  do
    receive do
      {ref, {:ok, reply}} ->
        miner = tasks
        |> Enum.find(fn {_miner, task} -> task.ref == ref end)
        |> elem(0)
        send(parent, {miner, reply})

      {ref, {:error, reason}} ->
        miner = tasks
        |> Enum.find(fn {_miner, task} -> task.ref == ref end)
        |> elem(0)
        tasks
        |> Enum.reject(fn {m, _task} -> m == miner end)
        |> yield_any(parent, [{miner, reason} | errors])

      {:DOWN, _ref, _, _pid, :normal} ->
        yield_any(tasks, parent, errors)

      {:DOWN, ref, _, _pid, reason} ->
        miner = tasks
        |> Enum.find(fn {_miner, task} -> task.ref == ref end)
        |> elem(0)
        tasks
        |> Enum.reject(fn {k, _task} -> k == miner end)
        |> yield_any(parent, [{miner, reason} | errors])

      msg ->
        IO.puts "Some other msg"
        IO.inspect msg
    end
  end

  defp yield_any([], parent, errors),
    do: send(parent, Enum.reverse(errors))


  # Inits the asynchronous operation task
  defp init_task(%Miner{} = miner, operation) do
    task = Task.async(fn ->
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
    {miner, task}
  end

end
