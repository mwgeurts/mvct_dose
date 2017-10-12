# TomoTherapy MVCT Dose Calculator

by Mark Geurts <mark.w.geurts@gmail.com>
<br>Copyright &copy; 2017, University of Wisconsin Board of Regents

The TomoTherapy&reg; MVCT Dose Calculator Tool is a GUI based standalone application written in MATLAB&reg; that facilitates estimation of the dose delivered during Mega-Voltage CT (MVCT) acquisition on a [TomoTherapy](http://www.accuray.com) Treatment System. 

Users can load a DICOM CT and RT Structure Set or a patient archive CT and structure set as patient inputs, drag to select a scan length and pitch, input an Image Value to Density Table (IVDT), then select from a list of provided beam models and calculate dose.  The MVCT acquisition may be further modified by adjusting the MLC sinogram, beam output, gantry period, and jaw width to study customized scanning scenarios.  The resulting dose calculation and Dose Volume Histogram (DVH) are displayed and available for export.

TomoTherapy is a registered trademark of Accuray Incorporated. MATLAB is a registered trademark of MathWorks Inc. 

## Installation

To install the TomoTherapy MVCT Dose Calculator Tool as a MATLAB App, download and execute the `MVCT Dose Calculator.mlappinstall` file from this directory. If using git, execute `git clone --recursive https://github.com/mwgeurts/mvct_dose`. See the [wiki](../../wiki/Installation-and-Use) for information on configuration parameters, setting up the calculation server, and adding beam models.

## Usage

To run this application, run the App or call `MVCTdose` from MATLAB. Once the application interface loads, select browse under inputs to load the CT and structure set inputs. Then enter the remaining inputs and click "Calculate Dose".

## License

Released under the GNU GPL v3.0 License.  See the [LICENSE](LICENSE) file for further details.
