# Building Archetypcal Urban Energy Model

## 1. Usage

To use this repository (once done the environment setup in the following section `2. Spine environment configuration`):
```shell
git clone https://github.com/EnergySystemAnalysis-ETH/ESAurban-SpineOpt.git
cd ESAurban-SpineOpt
# Julia project environment
julia --project=@.
# Conda python virtual env (only when using spinetoolbox)
conda activate spine-tools
(spine-tools) > spinetoolbox
```

## 2. Spine environment configuration

### I. spinetoolbox related `Python` packages

In OS terminal:
```shell
conda create -n spine-tools python
conda activate spine-tools
python -m pip install spinetoolbox==0.x.y
```
> Note: replace the `python` by `python=3.1x` for a specific version

### II. `Julia` packages

1. Activate `Julia` project environment **in OS terminal**

    ```shell
    cd path\to\ESAurban-SpineOpt
    julia --project=@.
    ```

2. (Cont.) Initialise project packages **in `Julia` console**

    ```shell
    julia> ]
    (ESAurban-SpineOpt) pkg> instantiate
    (ESAurban-SpineOpt) pkg> status
    ```

- (Optional) To enable `Julia` cells in Jupyter notebooks: 
	```julia
	using Pkg; Pkg.build("IJulia")
	```

### III. Config python interpreter for `PyCall.jl`

1. In OS terminal	
	
    ```shell
	conda activate spine-tools 
	cd path\to\ESAurban-SpineOpt
    (spine-tools) ..\ESAurban-SpineOpt> julia --project=@.
	```

2. (Cont.) In `Julia` console
	
	```julia
	ENV["PYTHON"] = Sys.which("python")
	using Pkg; Pkg.build("PyCall")
	```
    > Relaunch Julia with `julia --project=@.` to check which `Python` is being used by `PyCall`: `PyCall.pyprogramname` or `PyCall.python`
