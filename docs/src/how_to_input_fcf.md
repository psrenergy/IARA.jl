# How to Input a FCF File

Follow these steps to integrate a FCF (Future Cost Function) file into your study:

1. **Prepare the FCF File**  
   Ensure that the FCF file (`cuts.json`) is available in your study’s input directory.

2. **Load the Study**  
   Load your study database using the following command (make sure to replace `PATH` with your study path):
   ```julia
   db = IARA.load_study(PATH; read_only = false)
   ```

3. **Link the Time Series File**  
   Link the FCF file (`cuts.json`) to your study’s configuration using the code snippet below:
   ```julia
   IARA.link_time_series_to_file(
       db,
       "Configuration";
       fcf_cuts = "cuts.json",
   )
   ```

4. **Close the Study**  
   Once the file is linked, close the database:
   ```julia
   IARA.close_study!(db)
   ```

For a complete working example, refer to the [modify_case.jl](https://github.com/psrenergy/IARA.jl/tree/main/test/case_01/base_case_simulation/modify_case.jl) file in the `test/case_01/base_case_simulation` directory.

# Use cases for FCF Input

1. Minimum Cost Run:
   If you have already trained a policy and wish to run a decoupled simulation using that trained policy, you can input an FCF file to ensure that the simulation utilizes the expected cost function.
2. Clearing Simulations:
   - `HYBRID`: If you are running a clearing simulation with the `HYBRID` construction type, you may input a FCF file to define the water values for the simulation. This option is enabled when there are virtual reservoirs in the system and the `market_clearing_tiebreaker_weight_for_fcf` parameter is set to a value greater than zero. In that case, the FCF will be scaled according to the `market_clearing_tiebreaker_weight_for_fcf` value.
   - `COST_BASED`: If you are running a clearing simulation with the `COST_BASED` construction type, inputting an FCF file is **mandatory** to define the water values for the simulation.

!!! tip "Tip"
    If you are using the HYBRID construction type, providing an FCF file is optional, but strongly recommended. This will help ensure more accurate water values during the simulation.

!!! danger "Warning"
    When using the COST_BASED construction type, it is mandatory to input an FCF file. Failure to do so will result in an error during the simulation.