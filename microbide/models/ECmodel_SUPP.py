from __future__ import division
import sys, csv, os
import EClandscape as land
import ECMicrobideCore as model
import ECfunctions as funx
import numpy as np


###########################  GET CONDITIONS  ###################################

""" Code to runs the microbide model and generates site-by-species matrices."""

conditions = [['same', 'rand', 'rand'],
             ['differ', 'rand', 'rand'],
             ['same',  'env',  'env'],
             ['differ',  'env', 'env']]

""" conditions is a list of modeling parameters for different conceptual
    predictions representing extreme ends of a continuum of possible differences
    in environment and whether entering and exiting from dormancy has a
    stochastic component

    Conditions for...
        Conceptual prediction 1:
            Environments have the same effect
            Exiting and entering dormancy has a large stochastic component

        Conceptual prediction 2.
            Environments have different effects.
            Exiting and entering dormancy has a large stochastic component

        Conceptual prediction 3.
            Environments have the same effect
            Exiting and entering dormancy is environmental

        Conceptual prediction 4.
            Environments have different effects.
            Entering is environmental, Exiting is environmental

"""

####################  GENERATE SITE BY SPECIES DATA  ###########################

for j in range(10):
    num_patches = 20 # number of patches on each side of Evolution Canyon (EC)
    N = 2 * 10**6 # Starting total abundance across the landscape
    T = 10**7 # Time parameter

    lgp = round(np.random.uniform(0.8, 1), 4) # log-series parameter; underlying structure of regional pool
    im = round(np.random.uniform(0.8, 1), 4) # immigration rate
    dkern = round(10**np.random.uniform(-3, -1), 4) # dispersal kernel

    for ic, combo in enumerate(conditions):
        envDiff, enterD, exitD = combo

        landscapeLists = land.get_landscape(combo) # characterizing the landscape

        NRowXs, NRow1Ys, NRow2Ys, SRowXs, SRow1Ys = landscapeLists[0]
        SRow2Ys, Ncounts, Nverts, Scounts, Sverts = landscapeLists[1]

        COM = model.microbide(combo, Ncounts, Nverts, Scounts, Sverts, N, T, ic, lgp, im, dkern)
                                # run the model & return the communities

        nCOM, sCOM = funx.SpeciesInPatches(COM, NRowXs, NRow1Ys, NRow2Ys,
                                                SRowXs, SRow1Ys, SRow2Ys)

        SbyS = funx.get_SitebySpecies([nCOM, sCOM]) # get site by species matrix
        S = len(SbyS[0]) - 3 # first 3 columns are non-species data

        r1 = len(SbyS[0])
        for i, row in enumerate(SbyS): # checking to ensure correct format for SbyS
            r2 = len(row)

            if i%2 > 0 and sum(row[2:]) == 0: # first 3 columns are non-species data
                print 'there are no individuals in row', i

            if r1 != r2:
                print 'unequal sized rows in Site by Species matrix'
                sys.exit()
            r1 = r2


        mypath = os.path.dirname(os.path.realpath(__file__))
        path = os.path.join(os.path.split(mypath)[0], 'SbyS/supp')
        print('Output Path = '+str(path))

        directory = '/lgp='+str(round(lgp,4))+'_im='+str(round(im, 4))+'_dispkernel='+str(round(dkern, 4))

        if not os.path.exists(path+directory):
            os.makedirs(path+directory)

        fileName = os.path.join(path+directory, 'Condition'+str(ic+1))
        OUT = open(fileName + '.txt','w')
        writer = csv.writer(OUT, delimiter='\t')

        linedata = ['label', 'Group', 'numOtus']
        for s in range(S):
            linedata.append('Otu'+str(s))

        writer.writerow(linedata)

        for row in SbyS:
            if len(row) != r1:
                print 'row length has been corrupted'
                sys.exit()
            writer.writerow(row)

        OUT.close()
