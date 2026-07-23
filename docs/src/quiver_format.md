# **Quiver Format**

Quiver is a **data structure** designed for representing **time series data** with multiple dimensions, such as **periods, scenarios, subperiods, segments,** and more.
It is used in **IARA** for handling both **inputs and outputs** of the model.

The core concept of Quiver is to organize time series data using a set of dimensions for indexing and a set of attributes representing the values of the time series. This structure creates a table-like format that simplifies storage, retrieval, and analysis of time series data.

Quiver files can be stored in any format that supports a structured table with accompanying metadata. The table is stored in a **CSV** or **binary** format, while the metadata is stored in a **TOML** file.

### **Metadata (TOML Format)**
Metadata for a Quiver file is stored in a **TOML** file with the following structure:

| **Field**         | **Description** |
|-------------------|----------------|
| `version`        | The Quiver file format version. |
| `dimensions`     | Names of the dimensions used in the dataset. |
| `dimension_sizes` | Maximum number of elements in each dimension. |
| `initial_datetime`   | The start date of the time series, as an ISO 8601 string (`yyyy-mm-ddTHH:MM:SS`). |
| `time_dimensions` | The dimension(s) representing time (a file may have more than one). |
| `frequencies`      | The time interval between data points for each entry in `time_dimensions` (e.g., month, day, hour). |
| `unit`          | The unit of measurement (e.g., MW, $, etc.). |
| `labels`        | Names of the time series agents. |
---

Here's an example of a metadata file:

```toml
version = "1"
dimensions = ["period", "scenario", "subscenario", "subperiod"]
dimension_sizes = [6, 3, 4, 3]
initial_datetime = "2024-01-01T00:00:00"
time_dimensions = ["period"]
frequencies = ["monthly"]
unit = "$/MWh"
labels = ["Eastern", "Western"]
```

### **Data Storage Format**
The actual **time series data** is stored in **binary format** (`.qvr` file, efficient for large datasets and the authoritative artifact). A **CSV** copy (`.csv`) is produced alongside every output file for human readability, generated from the binary data rather than written directly.

#### **CSV Format Example**
```csv
period,scenario,subscenario,subperiod,Eastern,Western
1,1,1,1,10.0,10.0
1,1,1,2,-0.0,-0.0
1,1,1,3,50.0,300.0
```

For more information on how to read and write Quiver files, refer to the [Quiver.jl documentation](https://psrenergy.github.io/Quiver.jl/dev/).
