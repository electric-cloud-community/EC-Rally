
// RallyConfigList.java --
//
// RallyConfigList.java is part of ElectricCommander.
//
// Copyright (c) 2005-2010 Electric Cloud, Inc.
// All rights reserved.
//

package ecplugins.rally.client;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;

import com.google.gwt.user.client.ui.ListBox;
import com.google.gwt.xml.client.Document;
import com.google.gwt.xml.client.Node;
import com.google.gwt.xml.client.XMLParser;

import static com.electriccloud.commander.gwt.client.util.XmlUtil.getNodeByName;
import static com.electriccloud.commander.gwt.client.util.XmlUtil.getNodeValueByName;
import static com.electriccloud.commander.gwt.client.util.XmlUtil.getNodesByName;

public class RallyConfigList
{

    //~ Instance fields --------------------------------------------------------

    private final Map<String, RallyConfigInfo> m_configInfo =
        new TreeMap<String, RallyConfigInfo>();

    //~ Methods ----------------------------------------------------------------

    public void addConfig(
            String configName,
            String configServer)
    {
        m_configInfo.put(configName, new RallyConfigInfo(configServer));
    }

    public String parseResponse(String cgiResponse)
    {
        Document document     = XMLParser.parse(cgiResponse);
        Node     responseNode = getNodeByName(document, "response");
        String   error        = getNodeValueByName(responseNode, "error");

        if (error != null && !error.isEmpty()) {
            return error;
        }

        Node       configListNode = getNodeByName(responseNode, "cfgs");
        List<Node> configNodes    = getNodesByName(configListNode, "cfg");

        for (Node configNode : configNodes) {
            String configName   = getNodeValueByName(configNode, "name");
            String configServer = getNodeValueByName(configNode, "rally_url");

            addConfig(configName, configServer);
        }

        return null;
    }

    public void populateConfigListBox(ListBox lb)
    {

        for (String configName : m_configInfo.keySet()) {
            lb.addItem(configName);
        }
    }

    public Set<String> getConfigNames()
    {
        return m_configInfo.keySet();
    }

    public String getConfigServer(String configName)
    {
        return m_configInfo.get(configName).m_server;
    }

    public String getEditorDefinition(String configName)
    {
        return "EC-Rally";
    }

    public boolean isEmpty()
    {
        return m_configInfo.isEmpty();
    }

    public void setEditorDefinition(
            String configServer,
            String editorDefiniton)
    {
    }

    //~ Inner Classes ----------------------------------------------------------

    private class RallyConfigInfo
    {

        //~ Instance fields ----------------------------------------------------

        private String m_server;

        //~ Constructors -------------------------------------------------------

        public RallyConfigInfo(String server)
        {
            m_server = server;
        }
    }
}
