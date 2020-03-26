class Scenario:
    # Keep track of the number of scenarios created
    scenario_counter = 0


    def __init__(self,
                 name, # Scenario name
                 S, # Regional Population
                 market_share, #HospitalMarket Share (%) [0,100]
                 initial_infections, # Currently Known Regional Infections
                 current_hosp, # Currently Hospitalized COVID-19 Patients
                 n_days, # Number of days to simulate
                 doubling_time, # doubling time
                 relative_contact_rate, # Social distancing (% reduction in social contact [0,100])
                 recovery_days, # Days to recover
                 hosp_rate, # Hospitalization %(total infections [0,100])
                 icu_rate, # ICU %(total infections [0,100])
                 vent_rate, # Ventilated %(total infections [0,100])
                 hosp_los, # Hospital Length of Stay (days)
                 icu_los, # ICU Length of Stay (days)
                 vent_los): # vent Length of Stay (days))
        Scenario.scenario_counter += 1
        self.id= Scenario.scenario_counter
        self.name = name
        self.S = S
        self.market_share = market_share/100
        self.initial_infections = initial_infections
        self.current_hosp = current_hosp
        self.n_days = n_days
        self.doubling_time = doubling_time
        self.relative_contact_rate = relative_contact_rate/100
        self.recovery_days = recovery_days
        self.hosp_rate = hosp_rate/100
        self.icu_rate = icu_rate/100
        self.vent_rate = vent_rate/100
        self.hosp_los = hosp_los
        self.icu_los = icu_los
        self.vent_los = vent_los

    def get_param(self):
        param = []
        param.append(self.id)
        param.append(self.name)
        param.append(self.S)
        param.append(self.market_share)
        param.append(self.initial_infections)
        param.append(self.current_hosp)
        param.append(self.n_days)
        param.append(self.doubling_time)
        param.append(self.relative_contact_rate)
        param.append(self.recovery_days)
        param.append(self.hosp_rate)
        param.append(self.icu_rate)
        param.append(self.vent_rate)
        param.append(self.hosp_los)
        param.append(self.icu_los)
        param.append(self.vent_los)

        return param
