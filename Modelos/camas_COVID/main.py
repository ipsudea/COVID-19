import pandas as pd
import streamlit as st
import numpy as np
import altair as alt
from entities import Scenario


# The SIR model, one time step
def sir(y, beta, gamma, N):
    S, I, R = y
    Sn = (-beta * S * I) + S
    In = (beta * S * I - gamma * I) + I
    Rn = gamma * I + R
    if Sn < 0:
        Sn = 0
    if In < 0:
        In = 0
    if Rn < 0:
        Rn = 0

    scale = N / (Sn + In + Rn)
    return Sn * scale, In * scale, Rn * scale


# Run the SIR model forward in time
def sim_sir(S, I, R, beta, gamma, n_days, beta_decay=None):
    N = S + I + R
    s, i, r = [S], [I], [R]
    for day in range(n_days):
        y = S, I, R
        S, I, R = sir(y, beta, gamma, N)
        if beta_decay:
            beta = beta * (1 - beta_decay)
        s.append(S)
        i.append(I)
        r.append(R)

    s, i, r = np.array(s), np.array(i), np.array(r)
    return s, i, r

# Projected **census** of COVID-19 patients, accounting for arrivals and discharges at  hospitals"
def _census_table(projection_admits, hosp_los, icu_los, vent_los) -> pd.DataFrame:
    """ALOS for each category of COVID-19 case (total guesses)"""

    los_dict = {
        "hosp": hosp_los,
        "icu": icu_los,
        "vent": vent_los,
    }

    census_dict = dict()
    for k, los in los_dict.items():
        census = (
            projection_admits.cumsum().iloc[:-los, :]
            - projection_admits.cumsum().shift(los).fillna(0)
        ).apply(np.ceil)
        census_dict[k] = census[k]


    census_df = pd.DataFrame(census_dict)
    census_df["day"] = census_df.index
    census_df = census_df[["day", "hosp", "icu", "vent"]]
    # census_table = census_df[np.mod(census_df.index, 7) == 0].copy()
    census_table = census_df.copy()
    census_table.index = range(census_table.shape[0])
    census_table.loc[0, :] = 0
    census_table = census_table.dropna().astype(int)

    return census_table

# Graph comparing measure in three scenarios
def comparing_chart(s1: np.ndarray, s2: np.ndarray) -> alt.Chart:
    dat = pd.DataFrame({"Scenario1": s1, "Scenario2": s2})

    return (
        alt
        .Chart(dat.reset_index())
        .transform_fold(fold=["Scenario1", "Scenario2"])
        .mark_line()
        .encode(
            x=alt.X("index", title="Days from today"),
            y=alt.Y("value:Q", title="Case Volume"),
            tooltip=["key:N", "value:Q"],
            color="key:N"
        )
        .interactive()
    )

# Graph comparing measure in three scenarios
def comparing_chart3(s1: np.ndarray, s2: np.ndarray, s3: np.ndarray) -> alt.layer:
    dat = pd.DataFrame({"Scenario1": s1, "Scenario2": s2, "Scenario3": s3})

    base = alt.Chart(dat.reset_index()).transform_fold(fold=["Scenario1", "Scenario2", "Scenario3"]).encode(
        x=alt.X("index", title="Días desde hoy"),
        y=alt.Y("value:Q", title="Total de pacientes"),
        tooltip=["key:N", "value:Q"],
        color="key:N",
        text=alt.Text('max(daily):Q')
        )
    text = alt.Chart(dat.reset_index()).transform_fold(fold=["Scenario1", "Scenario2", "Scenario3"]).encode(
        x=alt.X("index", aggregate={'argmax': 'value'}),
        y=alt.Y('max(value):Q'),
        color="key:N",
        text=alt.Text('max(value):Q')
    )
    return (
        alt.layer(base.mark_line(),
                  text.mark_text(dy=-10, fontSize=16))
        .interactive()
    )


# Graph comparing measure in n  scenarios
# series represent a variable number of np.ndarrays
def comparing_chartn(*series) -> alt.Chart:
    series_dict = {}
    names = []

    i = 1
    for serie in series:
        name = "Scenario"+ str(i)
        names.append(name)
        i+=1
        series_dict[name] = serie
    dat =pd.DataFrame(series_dict)
    #print(dat)

    return (
        alt
        .Chart(dat.reset_index())
        #.transform_fold(fold=["Scenario1", "Scenario2", "Scenario3"])
        .transform_fold(fold=names)
        .mark_line()
        .encode(
            x=alt.X("index", title="Days from today"),
            y=alt.Y("value:Q", title="Case Volume"),
            tooltip=["key:N", "value:Q"],
            color="key:N"
        )
        .interactive()
    )


# Creates consolidated dataFrames
column_names = ["day", "susceptible", "infections",  "recovered",  "Scenario_id"]
cum_sir_raw = pd.DataFrame(columns = column_names)
column_names = ["day", "hosp", "icu", "vent", "Scenario_id"]
cum_projection = pd.DataFrame(columns = column_names)
cum_projection_admits = pd.DataFrame(columns = column_names)
#column_names = ["day", "hosp", "icu", "vent", "Scenario_id"]
cum_census = pd.DataFrame(columns = column_names)



scenario1 = Scenario(name = "Escenario 1 - Medidas de aislamiento efectivas en 30%",
                    S = 683832,
                    market_share = 100,
                    initial_infections = 52,
                    n_days = 365,
                    current_hosp = 2,
                    doubling_time = 4,
                    relative_contact_rate = 30,
                    recovery_days = 14.0,
                    hosp_rate = 2.5,
                    icu_rate = 0.75,
                    vent_rate = 0.65,
                    hosp_los = 10,
                    icu_los = 14,
                    vent_los = 14,
                    )

scenario2 = Scenario(name = "Escenario 2 - Medidas de aislamiento efectivas en 45%",
                    S = 683832,
                    market_share = 100,
                    initial_infections = 52,
                    n_days = 365,
                    current_hosp = 2,
                    doubling_time = 4,
                    relative_contact_rate = 45,
                    recovery_days = 14.0,
                    hosp_rate = 2.5,
                    icu_rate = 0.75,
                    vent_rate = 0.65,
                    hosp_los = 10,
                    icu_los = 14,
                    vent_los = 14,
                    )

scenario3 = Scenario(name = "Escenario 3 - Medidas de aislamiento efectivas en 60%",
                    S = 683832,
                    market_share = 100,
                    initial_infections = 52,
                    n_days = 365,
                    current_hosp = 2,
                    doubling_time = 4,
                    relative_contact_rate = 60,
                    recovery_days = 14.0,
                    hosp_rate = 2.5,
                    icu_rate = 0.75,
                    vent_rate = 0.65,
                    hosp_los = 10,
                    icu_los = 14,
                    vent_los = 14,
                    )

list_scenarios = [scenario1, scenario2, scenario3]

# List of lists of parameters for each scenario
data = []
for scn in list_scenarios:
    data.append(scn.get_param())
# Create the pandas DataFrame
scn_df = pd.DataFrame(data, columns = ['id',
                                   'name',
                                   'Regional_pop',
                                   'market_share',
                                   'initial_infections',
                                   'current_hosp',
                                   'n_days',
                                   'doubling_time',
                                   'relative_contact_rate',
                                   'recovery_days',
                                   'hosp_rate',
                                   'icu_rate',
                                   'vent_rate',
                                   'hosp_los',
                                   'icu_los',
                                   'vent_los'])
scn_df = scn_df.T

# Run model for each scenario
for scn in list_scenarios:
    S = scn.S
    market_share = scn.market_share
    initial_infections = scn.initial_infections
    n_days = scn.n_days
    current_hosp = scn.current_hosp
    doubling_time = scn.doubling_time
    relative_contact_rate = scn.relative_contact_rate
    recovery_days = scn.recovery_days
    hosp_rate = scn.hosp_rate
    icu_rate = scn.icu_rate
    vent_rate = scn.vent_rate
    hosp_los = scn.hosp_los
    icu_los = scn.icu_los
    vent_los = scn.vent_los

    # Total infections
    total_infections = current_hosp / market_share / hosp_rate

    # Detection probability
    detection_prob = initial_infections / total_infections

    # Initial conditions for
    S, I, R = S, initial_infections / detection_prob, 0

    # epidemiological values
    intrinsic_growth_rate = 2 ** (1 / doubling_time) - 1
    # mean recovery rate, gamma, (in 1/days).
    gamma = 1 / recovery_days
    # Contact rate, beta
    # {rate based on doubling time} / {initial S}
    beta = (intrinsic_growth_rate + gamma) / S * (1-relative_contact_rate)
    r_t = beta / gamma * S # r_t is r_0 after distancing
    r_naught = r_t / (1-relative_contact_rate)
    doubling_time_t = 1/np.log2(beta*S - gamma +1) # doubling time after distancing
    # Run the SIR model
    beta_decay = 0.0
    s, i, r = sim_sir(S, I, R, beta, gamma, n_days, beta_decay=beta_decay)

    # 1. DataFrames
    # Raw SIR Simulation Data (DataFrame sir_raw
    days = np.array(range(0, n_days + 1))
    data_list = [days, s, i, r]
    data_dict = dict(zip(["day", "susceptible", "infections", "recovered"], data_list))
    sir_raw = pd.DataFrame.from_dict(data_dict)
    sir_raw = (sir_raw.iloc[:, :]).apply(np.floor)
    # sir_raw = (sir_raw.iloc[::7, :]).apply(np.floor) # show weekly
    sir_raw.index = range(sir_raw.shape[0])
    sir_raw['Scenario_id'] = scn.id
    cum_sir_raw = pd.concat([cum_sir_raw, sir_raw], ignore_index=True, sort=False)

    # Resource consumption (beds, icu, vent) data
    hosp = i * hosp_rate * market_share
    icu = i * icu_rate * market_share
    vent = i * vent_rate * market_share

    days = np.array(range(0, n_days + 1))
    data_list = [days, hosp, icu, vent]
    data_dict = dict(zip(["day", "hosp", "icu", "vent"], data_list))
    projection = pd.DataFrame.from_dict(data_dict)
    projection['Scenario_id'] = scn.id
    cum_projection = pd.concat([cum_projection, projection], ignore_index=True, sort=False)

    # New admissions
    projection_admits = projection.iloc[:-1, :] - projection.shift(1)
    projection_admits[projection_admits < 0] = 0
    plot_projection_days = n_days - 10
    projection_admits["day"] = range(projection_admits.shape[0])
    projection_admits['Scenario_id'] = scn.id
    cum_projection_admits = pd.concat([cum_projection_admits, projection_admits], ignore_index=True, sort=False)

    # Census of patients along the time horizon
    census_table = _census_table(projection_admits, hosp_los, icu_los, vent_los)
    census_table['Scenario_id'] = scn.id
    cum_census = pd.concat([cum_census, census_table], ignore_index=True, sort=False)


# Dislplay it in local browser

def head():

    st.markdown("""
<link rel="stylesheet" href="https://www1.pennmedicine.org/styles/shared/penn-medicine-header.css">

<div class="penn-medicine-header__content">
    <a id="title" class="penn-medicine-header__title">Modelación de escenarios considerando como población toda la
    población de Antioquia</a>
</div>
    """, unsafe_allow_html=True)

    st.markdown(
        """Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vestibulum consequat eleifend nisi ut tristique. 
        Cras rutrum efficitur metus at consectetur. Donec non vestibulum massa. Pellentesque varius tristique ex ac 
        consectetur. Vestibulum in dolor eget nibh lacinia pellentesque nec in metus. Vivamus vulputate nunc at 
        libero fermentum varius. Duis ultricies in sapien id consectetur. Donec suscipit placerat elit, ac laoreet 
        augue viverra vel. Cras et ipsum odio. Cras pulvinar luctus sapien sed tempor. Maecenas sagittis est a 
        egestas hendrerit.""")


    return None

head()

# Analysis of number of infected individuals
st.subheader("Parámetros de los escenarios considerados")
st.dataframe(scn_df)

# Analysis of number of infected individuals
st.subheader("Número de personas infectadas en los distintos escenarios")

# Create the arrays of observations for each scenario
i_s1 = cum_sir_raw.loc[cum_sir_raw["Scenario_id"] == 1][['day', 'infections']]
i_s1.rename(columns = {'infections':'infectionsS1'}, inplace = True)
i_s2 = cum_sir_raw.loc[cum_sir_raw["Scenario_id"] == 2][['day', 'infections']]
i_s2.rename(columns = {'infections':'infectionsS2'}, inplace = True)
i_s3 = cum_sir_raw.loc[cum_sir_raw["Scenario_id"] == 3][['day', 'infections']]
i_s3.rename(columns = {'infections':'infectionsS3'}, inplace = True)

merged = pd.merge(left=i_s1,right=i_s2, left_on='day', right_on='day')
merged = pd.merge(left=merged,right=i_s3, left_on='day', right_on='day')
merged = merged[[ 'infectionsS1', 'infectionsS2', 'infectionsS3' ]].astype(int)
copy_merged = merged

s1 = merged['infectionsS1']
s2 = merged['infectionsS2']
s3 = merged['infectionsS3']


# Graph the series for each scenario in a single graph
st.altair_chart(comparing_chartn(s1, s2, s3), use_container_width=True)
# Print the dataframe in which the graph is based
st.dataframe(copy_merged)


# Analysis of number of hospitalized individuals
st.subheader("Número acumulado de pacientes hospitalizados")

# Create the arrays of observations for each scenario
cum_census = (cum_census.iloc[:, :]).apply(np.floor)
i_s1 = cum_census.loc[cum_census["Scenario_id"] == 1][['day', 'hosp']]
i_s1.rename(columns = {'hosp':'hospS1'}, inplace = True)
i_s2 = cum_census.loc[cum_census["Scenario_id"] == 2][['day', 'hosp']]
i_s2.rename(columns = {'hosp':'hospS2'}, inplace = True)
i_s3 = cum_census.loc[cum_census["Scenario_id"] == 3][['day', 'hosp']]
i_s3.rename(columns = {'hosp':'hospS3'}, inplace = True)

merged = pd.merge(left=i_s1,right=i_s2, left_on='day', right_on='day')
merged = pd.merge(left=merged,right=i_s3, left_on='day', right_on='day')
merged = merged[[ 'hospS1', 'hospS2', 'hospS3' ]].astype(int)

copy_merged = merged

s1 = merged['hospS1']
s2 = merged['hospS2']
s3 = merged['hospS3']

# Graph the series for each scenario in a single graph
st.altair_chart(comparing_chart3(s1, s2, s3), use_container_width=True)
# Print the dataframe in which the graph is based
st.dataframe(copy_merged)


# Analysis of number of individuals in ICU
st.subheader("Número acumulado de pacientes en UCE/UCI sin ventilación mecánica")

# Create the arrays of observations for each scenario
cum_census = (cum_census.iloc[:, :]).apply(np.floor)
i_s1 = cum_census.loc[cum_census["Scenario_id"] == 1][['day', 'icu']]
i_s1.rename(columns = {'icu':'icuS1'}, inplace = True)
i_s2 = cum_census.loc[cum_census["Scenario_id"] == 2][['day', 'icu']]
i_s2.rename(columns = {'icu':'icuS2'}, inplace = True)
i_s3 = cum_census.loc[cum_census["Scenario_id"] == 3][['day', 'icu']]
i_s3.rename(columns = {'icu':'icuS3'}, inplace = True)

merged = pd.merge(left=i_s1,right=i_s2, left_on='day', right_on='day')
merged = pd.merge(left=merged,right=i_s3, left_on='day', right_on='day')
merged = merged[[ 'icuS1', 'icuS2', 'icuS3' ]].astype(int)

copy_merged = merged

s1 = merged['icuS1']
s2 = merged['icuS2']
s3 = merged['icuS3']

# Graph the series for each scenario in a single graph
st.altair_chart(comparing_chart3(s1, s2, s3), use_container_width=True)
# Print the dataframe in which the graph is based
st.dataframe(copy_merged)


# Analysis of number of individuals in Vent
st.subheader("Número acumulado de pacientes en UCI con ventilación mécanica")

# Create the arrays of observations for each scenario
cum_census = (cum_census.iloc[:, :]).apply(np.floor)
i_s1 = cum_census.loc[cum_census["Scenario_id"] == 1][['day', 'vent']]
i_s1.rename(columns = {'vent':'ventS1'}, inplace = True)
i_s2 = cum_census.loc[cum_census["Scenario_id"] == 2][['day', 'vent']]
i_s2.rename(columns = {'vent':'ventS2'}, inplace = True)
i_s3 = cum_census.loc[cum_census["Scenario_id"] == 3][['day', 'vent']]
i_s3.rename(columns = {'vent':'ventS3'}, inplace = True)

merged = pd.merge(left=i_s1,right=i_s2, left_on='day', right_on='day')
merged = pd.merge(left=merged,right=i_s3, left_on='day', right_on='day')
merged = merged[[ 'ventS1', 'ventS2', 'ventS3' ]].astype(int)

copy_merged = merged

s1 = merged['ventS1']
s2 = merged['ventS2']
s3 = merged['ventS3']

# Graph the series for each scenario in a single graph
st.altair_chart(comparing_chart3(s1, s2, s3), use_container_width=True)
# Print the dataframe in which the graph is based
st.dataframe(copy_merged)
