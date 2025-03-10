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
| `dimension_size` | Maximum number of elements in each dimension. |
| `initial_date`   | The start date of the time series. |
| `time_dimension` | The dimension representing time. |
| `frequency`      | The time interval between data points (e.g., month, day, hour). |
| `unit`          | The unit of measurement (e.g., MW, $, etc.). |
| `labels`        | Names of the time series agents. |
---

Here's an example of a metadata file:

```toml
version = 1
dimensions = ["period", "scenario", "subscenario", "subperiod"]
dimension_size = [6, 3, 4, 3]
initial_date = "2024-01-01 00:00:00"
time_dimension = "period"
frequency = "monthly"
unit = "$/MWh"
labels = ["Eastern", "Western"]
```

### **Data Storage Format**
The actual **time series data** is stored in either:

- **CSV format** (human-readable)
- **Binary format** (efficient for large datasets)

#### **CSV Format Example**
```csv
period,scenario,subscenario,subperiod,Eastern,Western
1,1,1,1,10.0,10.0
1,1,1,2,-0.0,-0.0
1,1,1,3,50.0,300.0
```

For more information on how to read and write Quiver files, refer to the [Quiver.jl documentation](https://psrenergy.github.io/Quiver.jl/dev/).
