# Local input specification

No data, metadata extracts, credentials, cached downloads or derived datasets
are distributed. The programs do not promise to recover a historical snapshot
from current web services. Data must be obtained separately and placed locally.

## Pollution: main analysis

Four files are required below `FDID_SOURCE_ROOT` (default: `data`):

```text
raw/pollution/Catalagzi_Cumayani_2019.csv
raw/pollution/Catalagzi_Cumayani_2020.csv
raw/pollution/Trafik_2019.csv
raw/pollution/Trafik_2020.csv
```

| Column | Contract |
|---|---|
| `station` | Exactly `Catalagzi Cumayani` or `Trafik`, matching the filename |
| `ts` | Local wall-time label, `YYYY-MM-DD HH:00:00`, without offset |
| `SO2` | Numeric concentration in micrograms per cubic metre; missing values blank or `NA` |
| `Stationid` | Needed only for the optional geography audit; Ministry station UUID |

Negative and non-finite concentrations are treated as missing. Invalid
hour labels, wrong stations and conflicting duplicates must be resolved
before analysis. No clipping, winsorisation or weather adjustment is applied.

Station UUIDs:

- Cumayanı: `df9142f3-3b6c-46d6-8738-1316a6ef64dc`
- Trafik: `7058210e-a4b5-4b90-9e46-ec674d6e52cd`
- Kozlu (optional map audit): `be837236-0704-447c-8a43-ccce0f3ded55`

The pollution source labels the **end** of each hourly averaging interval.
A label at 2019-06-01 00:00 is the final hour of 2019-05-31. Supply annual
extracts or sufficiently padded periods, including this boundary record.
Classical interpolation may use observations on the adjacent day, so retain
observations surrounding both ends of the analysis windows. If adjacent-year
files for 2018/2021 are present, the classical reader also reads them to
complete annual boundaries; they do not add analysis dates. Their presence is
recorded in the generated checksum file. Exact reproduction requires the same
source snapshot and coverage, not merely identical filenames.

Timestamps are processed in a neutral UTC frame to preserve the displayed
Turkish clock labels. This is **not** conversion from Turkish local time to
UTC. The selected calendar is February 1–May 31 in each of 2019 and 2020.

Source: Türkiye's Ministry air-quality network, [official portal](https://www.havaizleme.gov.tr/)
and historical [station download service](https://sim.csb.gov.tr/STN/STN_Report/StationDataDownloadNew).
Existing project records say the original annual Ministry extracts were
reused because the service timed out; original retrieval timestamps are
unavailable. This audit uses those local extracts and does not establish
current historical-download availability. EEA matching and weather data are
not required by this appendix's core pipeline.

## Generation: `sources` mode

Supply `raw/generation/CATES_YYYY-MM.csv`, for years 2019/2020 and months
02/03/04/05. Required columns are `ts`, `total`, `unit`; `unit` is `CATES`,
`total` is finite nonnegative hourly generation in MWh, and `ts` runs from
00:00 on the first day through 23:00 on the final day of each month. Unlike the
pollution convention, generation labels are used as supplied for the monthly
coverage audit. Duplicate timestamps and missing hours cause failure.

Source: [EPİAŞ Transparency Platform](https://seffaflik.epias.com.tr/), real-time
plant-level generation, plant ID `688`. The check verifies all 2,880 hours in
February–May 2019 and all 2,904 hours in February–May 2020, with positive
production somewhere in 2019 and zero production throughout the 2020 window.
It does not independently verify permit decisions or investment dates.

## Optional study-area map

Also supply:

- `raw/stations_national.csv`: `id`, `name`, `city`, `operator`, `lon`, `lat`.
  This is the Ministry registry snapshot; station UUIDs must be unique.
- `raw/epias_powerplants.csv`: `id`, `name`, `eic`; IDs `688`, `2264`, `877`,
  `2065` identify ÇATES and ZETES I/II/III respectively.
- Kozlu 2019 and 2020 pollution extracts with `Stationid`, alongside the four
  main files above. These are used for identity checks, not main estimation.
- Generation files for ZETES I/II/III, named `ZETES_I_YYYY-MM.csv`,
  `ZETES_II_YYYY-MM.csv`, `ZETES_III_YYYY-MM.csv`, with the generation schema.
- `raw/cartography/ne_10m_land.zip`: Natural Earth 1:10m land polygons,
  original version 5.1.1, from the [land dataset page](https://www.naturalearthdata.com/downloads/10m-physical-vectors/10m-land/).

Station coordinates come from the supplied registry; descriptive facility
coordinates and their source notes are configured in `R/config.R`. The map
uses WGS84 / UTM zone 36N. Historical Kozlu location ambiguity and the coarse
shoreline mean this is an orientation figure, not surveyed stack geometry.
