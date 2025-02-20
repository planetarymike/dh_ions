################################################################################
# PARAMETERS.jl
# TYPE: (1) Model files - required
# DESCRIPTION: Just some standard global constants that need to get used 
# EVERYWHERE. Also the chemical reaction network.
# 
# Eryn Cangi
# Created December 2019
# Last edited: 12 November 2021
# Currently tested for Julia: 1.4.1
################################################################################

# **************************************************************************** #

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! #
# !!                      !!!!! SUPER IMPORTANT !!!!!                       !! #
# !!     !!! Check the following every time you run the simulation !!!      !! #
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! #

const sim_folder_name = "testing-neutrals-only"
const initial_atm_file = "converged_neutral_atmosphere.h5"
const final_atm_file = ""
const converge_which = "neutrals"
const dt_min_and_max = Dict("neutrals"=>[-1, 14], "ions"=>[-4, 6], "both"=>[-4, 14])
const rel_tol = 1e-6

# This stuff is mutable, but less likely to change.
const make_new_alt_grid = false
const use_nonzero_initial_profiles = true
const do_chem = true 
const do_trans = true 
const solarfile = "marssolarphotonflux_solarmean.dat" # you may replace 'mean' with 'max' or 'min'
# !!!!!!!!!!!!!!!!!!!!!!!!!!!! end check !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! #

# Sets whether photochemical equilibrium is assumed. Aids in converging ions and neutrals
# together. Generally leave it as is so the code determines it, but you can change it
# if need be
const assume_photochem_eq = converge_which == "both" ? true : false

# Some water stuff to control the general shape of the profile
const upper_lower_bdy = 80e5 # the uppermost layer at which water will be fixed, in cm
const upper_lower_bdy_i = Int64(upper_lower_bdy / 2e5) # the uppermost layer at which water will be fixed, in cm
const hygropause_alt = 40e5
const MR_mean_water = 1.38e-4

# Species name lists and Jrate symbol lists  ===================================

# Neutrals --------------------------------------------------------------------
const conv_neutrals = [:Ar, :CO, :CO2, :H, :H2, :H2O, :H2O2, :HO2, :HOCO, :N2, 
                       :O, :O1D, :O2, :O3, :OH,
                       :D, :DO2, :DOCO, :HD, :HDO, :HDO2, :OD];
const new_neutrals = [];

const neutral_species = [];
append!(neutral_species, conv_neutrals)
append!(neutral_species, new_neutrals)

# Ions -------------------------------------------------------------------------
const conv_ions = [:CO2pl];
const new_ions = []; 
const ion_species = [];
append!(ion_species, conv_ions)
append!(ion_species, new_ions)

# Full species list -------------------------------------------------------------
const all_species = [];
append!(all_species, neutral_species)
append!(all_species, ion_species)

# Photolysis and Photoionization rate symbol lists ----------------------------
const conv_Jrates = [# Original neutral photodissociation
                    :JCO2toCOpO,:JCO2toCOpO1D,:JO2toOpO,:JO2toOpO1D,
                    :JO3toO2pO,:JO3toO2pO1D,:JO3toOpOpO,:JH2toHpH,:JOHtoOpH,
                    :JOHtoO1DpH,:JHO2toOHpO,:JH2OtoHpOH,:JH2OtoH2pO1D,:JH2OtoHpHpO,
                    :JH2O2to2OH,:JH2O2toHO2pH,:JH2O2toH2OpO1D,

                    # Original deuterated neutral photodissociation
                    :JHDOtoHpOD, :JHDOtoDpOH, :JHDO2toOHpOD,
                    :JHDOtoHDpO1D, :JHDOtoHpDpO, :JODtoOpD, :JHDtoHpD, :JDO2toODpO,
                    :JHDO2toDO2pH, :JHDO2toHO2pD, :JHDO2toHDOpO1D, :JODtoO1DpD,

                    # New neutral photodissociation (from Roger)
                    # :JCO2toCpOpO, :JCO2toCpO2, :JCOtoCpO, # TODO: Incorporate these to the neutral model.
                  ];
const newJrates = [];
const Jratelist = [];
append!(Jratelist, conv_Jrates)
append!(Jratelist, newJrates)

# This dictionary specifies the species absorbing a photon for each J rate using regular expressions.
const absorber = Dict([x=>Symbol(match(r"(?<=J).+(?=to)", string(x)).match) for x in Jratelist])


# Other logical groupings -------------------------------------------------------
const D_bearing_species = [s for s in union(neutral_species, ion_species) if occursin('D', string(s))];
const D_ions = [s for s in ion_species if occursin('D', string(s))];
const N_neutrals = [s for s in neutral_species if occursin('N', string(s))];

# Short lived species, whose chemical lifetime is << diffusion timescale
const short_lived_species = [];# technically shortlived but count as longlived: :CH, :HCO, :HO2, :O3, :OH, :O1D, :DO2, :OD...
if assume_photochem_eq
    append!(short_lived_species, [])
    append!(short_lived_species, ion_species)
end

# Long lived species
const long_lived_species = setdiff(all_species, short_lived_species)

# Species participating in chem and transport -----------------------------------

# Non-participants
const no_chem_species = [:Ar, :N2];
const no_transport_species = [:Ar, :N2];

if converge_which == "neutrals"
    append!(no_chem_species, union(conv_ions, N_neutrals)) # This is because the N chemistry is intimiately tied up with the ions.
    append!(no_transport_species, union(conv_ions, N_neutrals, short_lived_species))
elseif converge_which == "ions"
    append!(no_chem_species, setdiff(conv_neutrals, N_neutrals))
    append!(no_transport_species, setdiff(conv_neutrals, N_neutrals))
elseif converge_which == "both"
    append!(no_transport_species, short_lived_species)
end

# Participants
const chem_species = setdiff(all_species, no_chem_species);
const transport_species = setdiff(all_species, no_transport_species);

# Active and inactive species 
const active_species = union(chem_species, transport_species)
const inactive_species = intersect(no_chem_species, no_transport_species)
const active_longlived = intersect(active_species, long_lived_species)
const active_shortlived = intersect(active_species, short_lived_species)

# To allow water to be active in the upper atmosphere but not the lower atmosphere, we need 
# its position with the active species vector 
const H2Oi = findfirst(x->x==:H2O, active_longlived)
const HDOi = findfirst(x->x==:HDO, active_longlived)

# **************************************************************************** #
# Annoyingly, this has to be here because D_bearing_species is only defined here.
# D group will have dashed lines; neutrals, solid (default)
const speciesstyle = Dict([s=>"--" for s in D_bearing_species]);

# Chemistry ====================================================================
# function to replace three body rates with the recommended expression
# threebody(k0, kinf) = :($k0*M/(1+$k0*M/$kinf)*0.6^((1+(log10($k0*M/$kinf))^2)^-1))
# threebodyca(k0, kinf) = :($k0/(1+$k0/($kinf/M))*0.6^((1+(log10($k0/($kinf*M)))^2)^-1))

threebody(k0, kinf) = :($k0 .* M ./ (1 .+ $k0 .* M ./ $kinf).*0.6 .^ ((1 .+ (log10.($k0 .* M ./ $kinf)) .^2).^-1.0))
threebodyca(k0, kinf) = :($k0 ./ (1 .+ $k0 ./ ($kinf ./ M)).*0.6 .^ ((1 .+ (log10.($k0 ./ ($kinf .* M))) .^2).^-1.0))

################################################################################
############################### REACTION NETWORK ###############################
################################################################################

# reactions and multipliers on base rates for deuterium reactions from Yung
# 1988; base rates from this work or Chaffin+ 2017. Note: below, H-ana means 
# the same reaction but with only H-bearing species.
const reactionnet = [   #Photodissociation
                     [[:CO2], [:CO, :O], :JCO2toCOpO],
                     [[:CO2], [:CO, :O1D], :JCO2toCOpO1D],
                     [[:O2], [:O, :O], :JO2toOpO],
                     [[:O2], [:O, :O1D], :JO2toOpO1D],
                     [[:O3], [:O2, :O], :JO3toO2pO],
                     [[:O3], [:O2, :O1D], :JO3toO2pO1D],
                     [[:O3], [:O, :O, :O], :JO3toOpOpO],
                     [[:H2], [:H, :H], :JH2toHpH],
                     [[:HD], [:H, :D], :JHDtoHpD],
                     [[:OH], [:O, :H], :JOHtoOpH],
                     [[:OH], [:O1D, :H], :JOHtoO1DpH],
                     [[:OD], [:O, :D], :JODtoOpD],
                     [[:OD], [:O1D, :D], :JODtoO1DpD],
                     [[:HO2], [:OH, :O], :JHO2toOHpO], # other branches should be here, but have not been measured
                     [[:DO2], [:OD, :O], :JDO2toODpO],
                     [[:H2O], [:H, :OH], :JH2OtoHpOH],
                     [[:H2O], [:H2, :O1D], :JH2OtoH2pO1D],
                     [[:H2O], [:H, :H, :O], :JH2OtoHpHpO],
                     [[:HDO], [:H, :OD], :JHDOtoHpOD], 
                     [[:HDO], [:D, :OH], :JHDOtoDpOH], 
                     [[:HDO], [:HD, :O1D], :JHDOtoHDpO1D], # inspiration from Yung89
                     [[:HDO], [:H, :D, :O], :JHDOtoHpDpO], # inspiration from Yung89
                     [[:H2O2], [:OH, :OH], :JH2O2to2OH],
                     [[:H2O2], [:HO2, :H], :JH2O2toHO2pH],
                     [[:H2O2], [:H2O, :O1D], :JH2O2toH2OpO1D],
                     [[:HDO2], [:OH, :OD], :JHDO2toOHpOD], # Yung89
                     [[:HDO2], [:DO2, :H], :JHDO2toDO2pH],
                     [[:HDO2], [:HO2, :D], :JHDO2toHO2pD],
                     [[:HDO2], [:HDO, :O1D], :JHDO2toHDOpO1D],

                     # recombination of O
                     [[:O, :O, :M], [:O2, :M], :(1.8 .* 3.0e-33 .* (300 ./ Tn) .^ 3.25)], # Deighan 2012 # Checked no dups 
                     [[:O, :O2, :N2], [:O3, :N2], :(5e-35 .* exp.(724 ./ Tn))], # Checked no dups 
                     [[:O, :O2, :CO2], [:O3, :CO2], :(2.5 .* 6.0e-34 .* (300 ./ Tn) .^ 2.4)], # Burkholder2020 # Checked no dups 
                     [[:O, :O3], [:O2, :O2], :(8.0e-12 .* exp.(-2060 ./ Tn))],  # Burkholder 2020
                     [[:O, :CO, :M], [:CO2, :M], :(2.2e-33 .* exp.(-1780 ./ Tn))],  # DUPLICATE - commented out in favor of Roger's reaction

                     # O1D attack
                     [[:O1D, :O2], [:O, :O2], :(3.3e-11 .* exp.(55 ./ Tn))], # Burkholder 2020 (upd. 31 Dec 2020)
                     [[:O1D, :O3], [:O2, :O2], :(2.4e-10)], # Burkholder 2020
                     [[:O1D, :O3], [:O, :O, :O2], :(2.4e-10)], # Burkholder 2020
                     [[:O1D, :CO2], [:O, :CO2], :(7.5e-11 .* exp.(115 ./ Tn))], # Burkholder 2020
                     ## O1D + H2
                     [[:O1D, :H2], [:H, :OH], :(1.2e-10)],  # Burkholder 2020
                     [[:O1D, :HD], [:H, :OD], :(0.41 .* 1.2e-10)], # Yung88: rate 0.41 .* H-ana (assumed). NIST 1.3e-10 @298K
                     [[:O1D, :HD], [:D, :OH], :(0.41 .* 1.2e-10)], # Yung88: rate 0.41 .* H-ana (assumed). NIST 1e-10 @298K
                     ## O1D + H2O
                     [[:O1D, :H2O], [:OH, :OH], :(1.63e-10 .* exp.(60 ./ Tn))], # Burkholder 2020
                     [[:O1D, :HDO], [:OD, :OH], :(((19 ./ 18) .^ -0.5) .* 1.63e-10 .* exp.(60 ./ Tn))], # Yung88: rate same as H-ana.

                     # loss of H2
                     [[:H2, :O], [:OH, :H], :(6.34e-12 .* exp.(-4000 ./ Tn))], # KIDA <-- Baulch, D. L. 2005
                     [[:HD, :O], [:OH, :D], :(4.40e-12 .* exp.(-4390 ./ Tn))], # NIST
                     [[:HD, :O], [:OD, :H], :(1.68e-12 .* exp.(-4400 ./ Tn))], # NIST 
                     # HD and H2 exchange
                     [[:H, :HD], [:H2, :D], :(6.31e-11 .* exp.(-4038 ./ Tn))], # TODO:CHECK rate: Yung89. NIST rate is from 1959 for 200-1200K.
                     [[:D, :H2], [:HD, :H], :(6.31e-11 .* exp.(-3821 ./ Tn))], # TODO:CHECK NIST (1986, 200-300K): 8.19e-13 .* exp.(-2700/Tn)

                     ## OH + H2
                     [[:OH, :H2], [:H2O, :H], :(2.8e-12 .* exp.(-1800 ./ Tn))], # Burkholder 2020
                     [[:OH, :HD], [:HDO, :H], :((3 ./ 20.) .* 2.8e-12 .* exp.(-1800 ./ Tn))], # Yung88: rate (3/20) .* H-ana. Sander2011: 5e-12 .* exp.(-2130 ./ Tn)
                     [[:OH, :HD], [:H2O, :D], :((3 ./ 20.) .* 2.8e-12 .* exp.(-1800 ./ Tn))], # see prev line
                     [[:OD, :H2], [:HDO, :H], :(2.8e-12 .* exp.(-1800 ./ Tn))], # Yung88: rate same as H-ana (assumed)
                     [[:OD, :H2], [:H2O, :D], :(0)], # Yung88 (assumed)

                     # recombination of H. Use EITHER the first line OR the 2nd.
                     #[[:H, :H, :CO2], [:H2, :CO2],:(1.6e-32 .* (298 ./ Tn) .^ 2.27)],
                     [[:H, :H, :M], [:H2, :M], :(1.6e-32 .* (298 ./ Tn) .^ 2.27)], # general version of H+H+CO2, rate: Justin Deighan.
                     [[:H, :D, :M], [:HD, :M], :(((2 ./ 1) .^ -0.5) .* 1.6e-32 .* (298 ./ Tn) .^ 2.27)], # Yung88: rate same as H-ana.

                     [[:H, :OH, :CO2], [:H2O, :CO2], :(1.9 .* 6.8e-31 .* (300 ./ Tn) .^ 2)], # NIST database
                     [[:H, :OD, :CO2], [:HDO, :CO2], :(((18 ./ 17) .^ -0.5) .* 1.9 .* 6.8e-31 .* (300 ./ Tn) .^ 2)], # not in Yung88. assumed rate
                     [[:D, :OH, :CO2], [:HDO, :CO2], :(((2 ./ 1) .^ -0.5) .* 1.9 .* 6.8e-31 .* (300 ./ Tn) .^ 2)], # not in Yung88. assumed rate

                     ## H + HO2
                     [[:H, :HO2], [:OH, :OH], :(7.2e-11)], # Burkholder 2020
                     [[:H, :HO2], [:H2, :O2], :(0.5 .* 6.9e-12)], # 0.5 is from Krasnopolsky suggestion to Mike
                     [[:H, :HO2], [:H2O, :O1D], :(1.6e-12)], # Burkholder 2020; they do not have O1D though
                     [[:H, :DO2], [:OH, :OD], :(((34 ./ 33) .^ -0.5) .* 7.2e-11)], # Yung88: rate same as H-ana. verified Yung89 3/28/18
                     [[:H, :DO2], [:HD, :O2], :(((34 ./ 33) .^ -0.5) .* 0.5 .* 6.9e-12)], # Yung88: rate same as H-ana. verified Yung89 3/28/18
                     [[:H, :DO2], [:HDO, :O1D], :(((34 ./ 33) .^ -0.5) .* 1.6e-12)], # Yung88: rate same as H-ana. verified Yung89 3/28/18. Yung88 has this as yielding HDO and O, not HDO and O1D
                     [[:D, :HO2], [:OH, :OD], :(0.71 .* 7.2e-11)], # Yung88: rate 0.71 .* H-ana (assumed). verified Yung89 3/28/18 (base: 7.05, minor disagreement)
                     [[:D, :HO2], [:HD, :O2], :(0.71 .* 0.5 .* 6.9e-12)], # Yung88: rate 0.71 .* H-ana (assumed). verified Yung89 3/28/18 (base 7.29, minor disagreement)
                     [[:D, :HO2], [:HDO, :O1D], :(0.71 .* 1.6e-12)], # Yung88: rate 0.71 .* H-ana (assumed). Changed to O1D to match what Mike put in 3rd line from top of this section.
                     [[:H, :DO2], [:HO2, :D], :(1e-10 ./ (0.54 .* exp.(890 ./ Tn)))], # Yung88 (assumed) .- turn off for Case 2
                     [[:D, :HO2], [:DO2, :H], :(1.0e-10)], # Yung88. verified Yung89 3/28/18 .- turn off for Case 2

                     ## H + H2O2
                     [[:H, :H2O2], [:HO2, :H2],:(2.81e-12 .* exp.(-1890 ./ Tn))], # verified NIST 4/3/18. Only valid for Tn>300K. No experiment for lower.
                     # [[:H, :HDO2], [:DO2, :H2], :(0)], # Cazaux2010: branching ratio = 0
                     # [[:H, :HDO2], [:HO2, :HD], :(0)], # Cazaux2010: BR = 0
                     # [[:D, :H2O2], [:DO2, :H2], :(0)], # Cazaux2010: BR = 0
                     # [[:D, :H2O2], [:HO2, :HD], :(0)], # Cazaux2010: BR = 0
                     [[:H, :H2O2], [:H2O, :OH],:(1.7e-11 .* exp.(-1800 ./ Tn))], # verified NIST 4/3/18
                     [[:H, :HDO2], [:HDO, :OH], :(0.5 .* 1.16e-11 .* exp.(-2110 ./ Tn))], # Cazaux2010: BR = 0.5. Rate for D + H2O2, valid 294<Tn<464K, NIST, 4/3/18
                     [[:H, :HDO2], [:H2O, :OD], :(0.5 .* 1.16e-11 .* exp.(-2110 ./ Tn))], # see previous line
                     [[:D, :H2O2], [:HDO, :OH], :(0.5 .* 1.16e-11 .* exp.(-2110 ./ Tn))], # see previous line
                     [[:D, :H2O2], [:H2O, :OD], :(0.5 .* 1.16e-11 .* exp.(-2110 ./ Tn))], # see previous line
                     [[:D, :HDO2], [:OD, :HDO], :(0.5 .* 1.16e-11 .* exp.(-2110 ./ Tn))], # TODO: Mass scaling for doubly deuterated? I previously added this and assumed rate.
                     [[:D, :HDO2], [:OH, :D2O], :(0.5 .* 1.16e-11 .* exp.(-2110 ./ Tn))], # see previous line

                     # Interconversion of odd H
                     ## H + O2
                     [[:H, :O2], [:HO2], threebody(:(2.0 .* 4.4e-32 .* (Tn ./ 300.) .^ -1.3), # Sander2011, 300K+. Yung89: 5.5e-32(Tn ./ 300) .^ -1.6, 7.5e-11 valid 200-300K.
                                                   :(7.5e-11 .* (Tn ./ 300.) .^ 0.2))],  # NIST has the temp info.
                     [[:D, :O2], [:DO2], threebody(:(2.0 .* 4.4e-32 .* (Tn ./ 300.) .^ -1.3), # Yung88: rate same as H-ana.
                                                   :(7.5e-11 .* (Tn ./ 300.) .^ 0.2))],

                     ## H + O3
                     [[:H, :O3], [:OH, :O2], :(1.4e-10 .* exp.(-470 ./ Tn))], # Burkholder 2020
                     [[:D, :O3], [:OD, :O2], :(0.71 .* 1.4e-10 .* exp.(-470 ./ Tn))], # Yung88, Yung89, NIST 4/3/18.
                     ## O + OH
                     [[:O, :OH], [:O2, :H], :(1.8e-11 .* exp.(180 ./ Tn))], # Burkholder 2020 Yung89: 2.2e-11 .* exp.(120/Tn) for both this and D analogue.
                     [[:O, :OD], [:O2, :D], :(((18 ./ 17) .^ -0.5) .* 1.8e-11 .* exp.(180 ./ Tn))], # Yung88: rate same as H-ana.
                     ## O + HO2
                     [[:O, :HO2], [:OH, :O2], :(3.0e-11 .* exp.(200 ./ Tn))], # Burkholder 2020
                     [[:O, :DO2], [:OD, :O2], :(((34 ./ 33) .^ -0.5) .* 3.0e-11 .* exp.(200 ./ Tn))], # Yung88: rate same as H-ana. 
                     ## O + H2O2
                     [[:O, :H2O2], [:OH, :HO2], :(1.4e-12 .* exp.(-2000 ./ Tn))], # Sander2011. verified NIST 4/3/18.
                     [[:O, :HDO2], [:OD, :HO2], :(0.5 .* ((35 ./ 34) .^ -0.5) .* 1.4e-12 .* exp.(-2000 ./ Tn))], # Yung88, Yung89
                     [[:O, :HDO2], [:OH, :DO2], :(0.5 .* ((35 ./ 34) .^ -0.5) .* 1.4e-12 .* exp.(-2000 ./ Tn))], # Modifier added by me
                     ## OH + OH
                     [[:OH, :OH], [:H2O, :O], :(1.8e-12)], # Burkholder 2020
                     [[:OD, :OH], [:HDO, :O], :(((18 ./ 17) .^ -0.5) .* 1.8e-12)], 
                     [[:OH, :OH], [:H2O2], threebody(:(1.3 .* 6.9e-31 .* (Tn ./ 300.) .^ -1.0), :(2.6e-11))], # Burkholder2020. Why 1.3? Reviewer suggestion to adjust for mars?
                     [[:OD, :OH], [:HDO2], threebody(:(1.3 .* 6.9e-31 .* (Tn ./ 300.) .^ -1.0), :(2.6e-11))], # Yung88: rate same as H-ana
                     ## OH + O3
                     [[:OH, :O3], [:HO2, :O2], :(1.7e-12 .* exp.(-940 ./ Tn))], # Sander2011, temp by NIST 220-450K. Yung89: 1.6 not 1.7 -> temp 200-300K by NIST (older info)
                     [[:OD, :O3], [:DO2, :O2], :(((18 ./ 17) .^ -0.5) .* 1.7e-12 .* exp.(-940 ./ Tn))],
                     ## OH + HO2
                     [[:OH, :HO2], [:H2O, :O2], :(4.8e-11 .* exp.(250 ./ Tn))], # verified NIST 4/3/18. Yung89: 4.6e-11 .* exp.(230/Tn) for this and next 2.
                     [[:OH, :DO2], [:HDO, :O2], :(((34 ./ 33) .^ -0.5) .* 4.8e-11 .* exp.(250 ./ Tn))], # Yung88: same as H-ana.
                     [[:OD, :HO2], [:HDO, :O2], :(((18 ./ 17) .^ -0.5) .* 4.8e-11 .* exp.(250 ./ Tn))], # Yung88: same as H-ana.
                     ## OH + H2O2
                     [[:OH, :H2O2], [:H2O, :HO2], :(2.9e-12 .* exp.(-160 ./ Tn))], # NIST+KIDA 4/3/18, valid 240-460K. Yung89: 3.3e-12 .* exp.(-200/Tn). Sander2011 recommends an average value of 1.8e-12, but this seems too high for martian temps
                     [[:OD, :H2O2], [:HDO, :HO2], :(((18 ./ 17) .^ -0.5) .* 2.9e-12 .* exp.(-160 ./ Tn))], # Yung88: same as H-ana (assumed)
                     [[:OD, :H2O2], [:H2O, :DO2], :(0)],  # Yung88 (assumed)
                     [[:OH, :HDO2], [:HDO, :HO2], :(0.5 .* ((35 ./ 34) .^ -0.5) .* 2.9e-12 .* exp.(-160 ./ Tn))], # Yung88: rate 0.5 .* H-ana.
                     [[:OH, :HDO2], [:H2O, :DO2], :(0.5 .* ((35 ./ 34) .^ -0.5) .* 2.9e-12 .* exp.(-160 ./ Tn))], # Yung88: rate 0.5 .* H-ana.
                     ## HO2 + O3
                     [[:HO2, :O3], [:OH, :O2, :O2], :(1.0e-14 .* exp.(-490 ./ Tn))], # Sander2011. Yung89: 1.1e-14 .* exp.(-500/Tn). KIDA 250-340K: 2.03e-16 .* (Tn ./ 300) .^ 4.57 .* exp.(693/Tn). All give comparable rate values (8.6e-16 to 1e-15 at 200K)
                     [[:DO2, :O3], [:OD, :O2, :O2], :(((34 ./ 33) .^ -0.5) .* 1.0e-14 .* exp.(-490 ./ Tn))], # Yung88: same as H-ana (assumed)
                     ## HO2 + HO2
                     [[:HO2, :HO2], [:H2O2, :O2], :(3.0e-13 .* exp.(460 ./ Tn))], # Burkholder2020. Yung89: 2.3e-13 .* exp.(600/Tn). KIDA 230-420K: 2.2e-13 .* exp.(600/Tn)
                     [[:DO2, :HO2], [:HDO2, :O2], :(((34 ./ 33) .^ -0.5) .* 3.0e-13 .* exp.(460 ./ Tn))], # Yung88: same as H-ana (assumed)
                     [[:HO2, :HO2, :M], [:H2O2, :O2, :M], :(2 .* 2.1e-33 .* exp.(920 ./ Tn))], # Burkholder2020.
                     [[:HO2, :DO2, :M], [:HDO2, :O2, :M], :(((34 ./ 33) .^ -0.5) .* 2 .* 2.1e-33 .* exp.(920 ./ Tn))], # added 3/13 with assumed same rate as H analogue

                     ## OH + D or OD + H (no non-deuterated analogues)
                     [[:OD, :H], [:OH, :D], :(3.3e-9 .* (Tn .^ -0.63) ./ (0.72 .* exp.(717 ./ Tn)))], # rate: Yung88. NIST (Howard82): 5.25E-11 .* (Tn/298) .^ -0.63  .- turn off for Case 2
                     [[:OH, :D], [:OD, :H], :(3.3e-9 .* Tn .^ -0.63)], # Yung88  .- turn off for Case 2

                     # CO2 recombination due to odd H
                     [[:CO, :OH], [:CO2, :H], threebodyca(:(1.5e-13 .* (Tn ./ 300.) .^ 0.6), :(2.1e9 .* (Tn ./ 300.) .^ 6.1))], # Sander2011
                     [[:CO, :OD], [:CO2, :D], threebodyca(:(1.5e-13 .* (Tn ./ 300.) .^ 0.6), :(2.1e9 .* (Tn ./ 300.) .^ 6.1))], # Yung88: same as H-ana.
                     [[:OH, :CO], [:HOCO], threebody(:(5.9e-33 .* (Tn ./ 300.) .^ -1.4), :(1.1e-12 .* (Tn ./ 300.) .^ 1.3))], # Sander2011
                     [[:OD, :CO], [:DOCO], threebody(:(5.9e-33 .* (Tn ./ 300.) .^ -1.4), :(1.1e-12 .* (Tn ./ 300.) .^ 1.3))],

                     [[:HOCO, :O2], [:HO2, :CO2], :(2.09e-12)], # verified NIST 4/3/18
                     [[:DOCO, :O2], [:DO2,:CO2], :(((46 ./ 45) .^ -0.5) .* 2.09e-12)],  # assumed?

                     # CO2+ attack on molecular hydrogen
                     [[:CO2pl, :H2], [:CO2, :H, :H], :(8.7e-10)], # from Kras 2010 ./ Scott 1997
                     [[:CO2pl, :HD], [:CO2pl, :H, :D], :((2/5) .* 8.7e-10)] 
                     ];