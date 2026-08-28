Grid operators are becoming more concerned about safety and service quality as
Photovoltaic (PV) Electricity Generation in power distribution systems keeps spreading.
The reliability of the power system is impacted by the intrinsic variability of PV power
generation, which is mostly caused by weather circumstances. To develop
efficient monitoring and control schemes for distribution grids, reliable forecasting of
the solar resource at several time horizons that are related to regulation, scheduling,
dispatching, and unit commitment, are necessary. PV power generation forecasting
can result from forecasting Global Horizontal Irradiance (GHI), which is the total amount of
shortwave radiation is received from above by a surface horizontal to the ground.
A comparative study of machine learning methods is given in this project.
As electricity is not easy to store; supply and demand must be always balanced by grid operators.
Due to the intermittent nature of the solar resource, the deployment of Photovoltaic (PV) power
generation makes the power grid balance more complex situations using conventional tools. This
project, which uses a predictive management strategy, is a stepping-stone to more efficient realtime monitoring and optimization of grid operation.
Solar radiation is an important parameter for solar energy research but is not available for most
of the sites due to the non-availability of solar radiation measuring equipment at the
meteorological stations. Therefore, it is essential to predict solar radiation for a location using
commonly measured meteorological variables. Solar radiation can be divided into three
components at the ground: global, diffuse, and direct. The global component is the sum of the
two others. While solar concentrator systems require knowledge of the direct solar component,
the precise knowledge of the global horizontal solar irradiation is very important in the design,
sizing, and production forecasting of thermal and photovoltaic solar systems.
The GHI score depends on several parameters such as precipitation, atmospheric pressure,
relative humidity, air temperature, wind direction, and wind speed. But their proper relation is
unknown. Our objective is to find a relation between GHI and these parameters. The train.csv
file comes with an ID for each GHI recording event and 6 other parameters. We will now prepare
an algorithm that can predict GHI with the minimum error possible. We will predict our model
on the cross-validation set and measure the accuracy. The accuracy metric is the RMSE score. A
lower RMSE score implies better and more accurate prediction.
We have used Python and some other python libraries (NumPy, Pandas, TensorFlow, Matplotlib,
SK-learn) in this project. We used LSTM (Long Short-Term Memory), SNN (Spiking Neural
Network), and FNN (Feedforward Neural Network) as our core training model and a stacked
model of these three to reach the highest prediction-accuracy score. We used RMSE Score as our
error evaluation parameters
