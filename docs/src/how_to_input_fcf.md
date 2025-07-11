# How to Input an FCF File

Follow these steps to integrate an FCF (Future Cost Function) file into your study:

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