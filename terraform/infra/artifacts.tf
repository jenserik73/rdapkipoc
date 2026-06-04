resource "oci_artifacts_container_repository" "rdap_chatbot_container_repository" {
    #Required
    compartment_id = local.compartment_id
    display_name = local.container_repository_display_name

    #Optional
    is_immutable = local.container_repository_is_immutable
    is_public = local.container_repository_is_public
    readme {
        #Required
        content = local.container_repository_readme_content
        format = local.container_repository_readme_format
    }
}
