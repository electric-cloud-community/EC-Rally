
// CreateConfiguration.java --
//
// CreateConfiguration.java is part of ElectricCommander.
//
// Copyright (c) 2005-2016 Electric Cloud, Inc.
// All rights reserved.
//

package ecplugins.rally.client;

import java.util.Collection;
import java.util.HashMap;
import java.util.Map;

import com.google.gwt.http.client.Request;
import com.google.gwt.http.client.RequestCallback;
import com.google.gwt.http.client.RequestException;
import com.google.gwt.http.client.Response;
import com.google.gwt.user.client.ui.Anchor;

import ecinternal.client.InternalFormBase;

import ecinternal.client.ui.CustomEditorLoader;

import com.electriccloud.commander.gwt.client.requests.CgiRequestProxy;
import com.electriccloud.commander.client.requests.RunProcedureRequest;
import com.electriccloud.commander.client.responses.DefaultRunProcedureResponseCallback;
import com.electriccloud.commander.client.responses.RunProcedureResponse;
import com.electriccloud.commander.gwt.client.ui.CredentialEditor;
import com.electriccloud.commander.gwt.client.ui.CredentialEditor.CredentialType;
import com.electriccloud.commander.gwt.client.ui.FormBuilder;
import com.electriccloud.commander.gwt.client.ui.FormTable;
import com.electriccloud.commander.gwt.client.ui.SimpleErrorBox;
import com.electriccloud.commander.gwt.client.util.CommanderUrlBuilder;

import static ecinternal.client.InternalComponentBaseFactory.getPluginName;

import static com.electriccloud.commander.gwt.client.util.CommanderUrlBuilder.createPageUrl;
import static com.electriccloud.commander.gwt.client.util.CommanderUrlBuilder.createUrl;

/**
 * Create Rally Configuration.
 */
public class CreateConfiguration
    extends InternalFormBase
{

    //~ Constructors -----------------------------------------------------------

    public CreateConfiguration()
    {
        super("New Rally Configuration", "Rally Configurations");

        CommanderUrlBuilder urlBuilder = createPageUrl(getPluginName(),
                "configurations");

        setDefaultRedirectToUrl(urlBuilder.buildString());
    }

    //~ Methods ----------------------------------------------------------------

    @Override protected FormTable initializeFormTable()
    {
        return getUIFactory().createFormBuilder();
    }

    @Override protected void load()
    {
        FormBuilder fb = (FormBuilder) getFormTable();

        setStatus("Loading...");

        CustomEditorLoader loader = new CustomEditorLoader(fb, this);

        loader.setCustomEditorPath("/plugins/EC-Rally"
                + "/project/ui_forms/CreateConfigForm");
        loader.load();
        clearStatus();
    }

    @Override protected void submit()
    {
        setStatus("Saving...");
        clearAllErrors();

        FormBuilder fb = (FormBuilder) getFormTable();

        if (!fb.validate()) {
            clearStatus();

            return;
        }

        // Build runProcedure request
        RunProcedureRequest request = getRequestFactory()
                .createRunProcedureRequest();

        request.setProjectName("/plugins/EC-Rally/project");
        request.setProcedureName("CreateConfiguration");

        Map<String, String> params           = fb.getValues();
        Collection<String>  credentialParams = fb.getCredentialIds();

        for (String paramName : params.keySet()) {

            if (credentialParams.contains(paramName)) {
                CredentialEditor credential = fb.getCredential(paramName);
                CredentialType   credentialType  = credential.getCredentialType();

                String           scredentialType = CredentialType.PASSWORD
                        .getName();

                if (credentialType == CredentialType.CHOOSE) {
                    scredentialType = CredentialType.CHOOSE.getName();
                }
                else if (credentialType == CredentialType.KEY) {
                    scredentialType = CredentialType.KEY.getName();
                    request.addActualParameter("credentialType",
                            scredentialType);
                }
                
                request.addCredentialParameter(paramName,
                    credential.getUsername(), credential.getPassword());
            }
            else {
                request.addActualParameter(paramName, params.get(paramName));
            }
        }

        // Launch the procedure
        request.setCallback(new DefaultRunProcedureResponseCallback(this) {
                @Override public void handleResponse(
                        RunProcedureResponse response)
                {

                    if (getLog().isDebugEnabled()) {
                        getLog().debug(
                            "Commander runProcedure request returned jobId: "
                                + response.getJobId());
                    }

                    waitForJob(response.getJobId().toString());
                }
            });

        if (getLog().isDebugEnabled()) {
            getLog().debug("Issuing Commander request: " + request);
        }

        doRequest(request);
    }

    private void waitForJob(final String jobId)
    {
        CgiRequestProxy     cgiRequestProxy = new CgiRequestProxy(
                getPluginName(), "rallyMonitor.cgi");
        Map<String, String> cgiParams       = new HashMap<String, String>();

        cgiParams.put("jobId", jobId);

        // Pass debug flag to CGI, which will use it to determine whether to
        // clean up a successful job
        if ("1".equals(getGetParameter("debug"))) {
            cgiParams.put("debug", "1");
        }

        try {
            cgiRequestProxy.issueGetRequest(cgiParams, new RequestCallback() {
                    @Override public void onError(
                            Request   request,
                            Throwable exception)
                    {
                        addErrorMessage("CGI request failed: ", exception);
                    }

                    @Override public void onResponseReceived(
                            Request  request,
                            Response response)
                    {
                        String responseString = response.getText();

                        if (getLog().isDebugEnabled()) {
                            getLog().debug(
                                "CGI response received: " + responseString);
                        }

                        if (responseString.startsWith("Success")) {

                            // We're done!
                            cancel();
                        }
                        else {
                            SimpleErrorBox      error      = getUIFactory()
                                    .createSimpleErrorBox(
                                        "Error occurred during configuration creation: "
                                        + responseString);
                            CommanderUrlBuilder urlBuilder = createUrl(
                                    "jobDetails.php").setParameter("jobId",
                                    jobId);

                            error.add(
                                new Anchor("(See job for details)",
                                    urlBuilder.buildString()));
                            addErrorMessage(error);
                        }
                    }
                });
        }
        catch (RequestException e) {
            addErrorMessage("CGI request failed: ", e);
        }
    }
}
